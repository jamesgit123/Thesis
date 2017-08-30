
import std.algorithm;
import std.array;
import std.conv;
import std.bitmanip;
import std.stdio;
import std.string;
import std.regex;

Machine delegate()[string] machines;

void registerMachine(string name, Machine delegate() create)
{
    assert(name !in machines);
    machines[name] = create;
}

enum AddressSpace
{
    data = 0,
    instruction = 1,
    both = 2,
}

class MemoryMapping
{
    uint base;
    uint length;
    AddressSpace space;

    this(uint base, uint length,  AddressSpace space)
    {
        this.base = base;
        this.length = length;
        this.space = space;
    }

    void cycle()
    {
    }

    bool interrupt()
    {
        assert(0);
    }

    bool inRange(uint addr)
    {
        return addr >= base && addr < base + length;
    }

    ubyte read1(uint addr)
    {
        assert(0, "read1 not implemented");
    }
    ushort read2(uint addr)
    {
        assert(0, "read2 not implemented");
    }
    uint read4(uint addr)
    {
        assert(0, "read4 not implemented");
    }
    ulong read8(uint addr)
    {
        assert(0, "read8 not implemented");
    }

    void write1(uint addr, ubyte value)
    {
        assert(0, "write1 not implemented");
    }
    void write2(uint addr, ushort value)
    {
        assert(0, "write2 not implemented");
    }
    void write4(uint addr, uint value)
    {
        assert(0, "write4 not implemented");
    }
    void write8(uint addr, ulong value)
    {
        assert(0, "write8 not implemented");
    }
}

class FileMemoryMapping : MemoryMapping
{
    ubyte[] mem;
    bool[] wasinit;
    bool little;
    bool initcheck;

    this(uint base, uint length, bool little, AddressSpace space, File fh, bool initcheck)
    {
        super(base, length, space);
        mem = new ubyte[](length);
        fh.seek(0);
        auto numinit = fh.rawRead(mem[]).length;
        wasinit = new bool[](length);
        wasinit[0..numinit] = true;
        this.little = little;
        if (little)
        {
            foreach(i; 0..length/4)
            {
                swap(mem[i*4+0], mem[i*4+3]);
                swap(mem[i*4+1], mem[i*4+2]);
            }
        }
        this.initcheck = initcheck;
    }

    T read(T)(uint addr)
    {
        if (initcheck)
            foreach(i; 0..T.sizeof)
                assert(wasinit[addr - base + i], "Uninitialized read at %08X".format(addr + i));

        auto bytes = mem[addr - base..$];

        if (little)
            return littleEndianToNative!T(bytes[0..T.sizeof]);
        else
            return bigEndianToNative!T(bytes[0..T.sizeof]);
    }

    override ubyte read1(uint addr)
    {
        return read!ubyte(addr);
    }
    override ushort read2(uint addr)
    {
        return read!ushort(addr);
    }
    override uint read4(uint addr)
    {
        return read!uint(addr);
    }
    override ulong read8(uint addr)
    {
        return read!ulong(addr);
    }

    void write(T)(uint addr, T value)
    {
        foreach(i; 0..T.sizeof)
            wasinit[addr - base + i] = true;

        auto bytes = mem[addr - base..$];

        if (little)
            bytes[0..T.sizeof] = nativeToLittleEndian!T(value);
        else
            bytes[0..T.sizeof] = nativeToBigEndian!T(value);
    }

    override void write1(uint addr, ubyte value)
    {
        write!ubyte(addr, value);
    }
    override void write2(uint addr, ushort value)
    {
        write!ushort(addr, value);
    }
    override void write4(uint addr, uint value)
    {
        write!uint(addr, value);
    }
    override void write8(uint addr, ulong value)
    {
        write!ulong(addr, value);
    }
}

class UartDataSource
{
    abstract bool empty();
    abstract ubyte read();
    abstract bool full();
    abstract void write(ubyte value);
}

class FileDataSource : UartDataSource
{
    File fin;
    File fout;
    ubyte c;
    bool _empty;
    this(File fin, File fout)
    {
        this.fin = fin;
        this.fout = fout;
        _empty = true;
    }
    void updateFiles()
    {
        if (!_empty)
            return;
        if (fin.eof())
        {
            _empty = true;
            return;
        }
        auto r = fin.rawRead((&c)[0..1]);
        _empty = r.length == 0;
    }
    override bool empty()
    {
        updateFiles();
        return _empty;
    }
    override ubyte read()
    {
        updateFiles();
        assert(!_empty);
        _empty = true;
        return c;
    }
    override bool full()
    {
        return false;
    }
    override void write(ubyte value)
    {
        fout.rawWrite((&value)[0..1]);
        fout.flush();
    }
}

class SocketDataSource : UartDataSource
{
    import std.socket;
    Socket listener;
    Socket sock;
    bool _empty;
    this(ushort port)
    {
        listener = new TcpSocket();
        listener.blocking = false;
        listener.bind(new InternetAddress(port));
        listener.listen(1);
        _empty = true;
    }
    void updateSockets()
    {
        _empty = true;
        if (!sock)
        {
            try
            {
                sock = listener.accept();
                sock.blocking = false;
            }
            catch (SocketAcceptException)
            {
            }
        }
        else if (sock.isAlive())
        {
            ubyte[1] buf;
            auto n = sock.receive(buf[], SocketFlags.PEEK);
            _empty = n <= 0;
            if (n == 0)
            {
                listener.listen(1);
                sock = null;
            }
        }
    }
    override bool empty()
    {
        updateSockets();
        return _empty;
    }
    override ubyte read()
    {
        updateSockets();
        assert(!_empty);
        ubyte[1] buf;
        auto n = sock.receive(buf[]);
        return buf[0];
    }
    override bool full()
    {
        updateSockets();
        return !sock || !sock.isAlive();
    }
    override void write(ubyte value)
    {
        updateSockets();
        ubyte[1] buf = [value];
        sock.send(buf[]);
    }
}

class UartMemoryMapping : MemoryMapping
{
    UartDataSource fio;
    bool ienable;
    bool itriggered_tx;
    bool itriggered_rx;
    ubyte[] rx;
    ubyte[] tx;
    int txdelay;
    bool waitingforreset = false;

    enum txchardelay = 1;
    enum txbufferlen = 16;

    this(uint base, UartDataSource fio)
    {
        super(base, 0x1000, AddressSpace.data);
        this.fio = fio;
    }

    override void cycle()
    {
        if (!waitingforreset && !fio.empty())
        {
            auto c = fio.read();
            auto oldrxlen = rx.length;
            rx ~= c;
            if (!oldrxlen)
                itriggered_rx = true; // rx non-empty
        }

        if (txdelay)
        {
            assert(tx.length);
            txdelay--;
            if (!txdelay)
            {
                if (fio.full())
                {
                    txdelay = 1;
                }
                else
                {
                    fio.write(tx[0]);
                    tx = tx[1..$];
                    if (tx.length)
                        txdelay = txchardelay;
                    else
                        itriggered_tx = true; // empty
                }
            }
        }
    }

    override bool interrupt()
    {
        return ienable && (itriggered_rx || itriggered_tx);
    }

    override uint read4(uint addr)
    {
        switch (addr - base)
        {
        case 0x0:
            // pop one byte
            if (rx.length)
            {
                auto value = rx[0];
                rx = rx[1..$];
                itriggered_rx = false;
                return value;
            }
            assert(0);
        case 0x4:
            return 0x00000000;
        case 0x8:
            // hack to clear interrupt on status read
            // since we don't support edge-triggered interrupts yet
            itriggered_tx = false;
            // 0 - RX FIFO Valid
            // 1 - RX FIFO Full
            // 2 - TX FIFO Empty
            // 3 - TX FIFO Full
            // 4 - Interrupt enabled
            // 5 - Overrun error
            // 6 - Frame Error
            // 7 - Parity Error
            uint status;
            status |= (rx.length != 0) << 0;
            status |= (txdelay == 0) << 2;
            status |= (txdelay != 0) << 3;
            status |= ienable << 4;
            return status;
        case 0xC:
            return 0x00000000;
        default:
            assert(0, "Invalid read from unmapped uart register");
        }
    }

    override void write4(uint addr, uint value)
    {
        switch (addr - base)
        {
        case 0x0:
            break;
        case 0x4:
            if (tx.length < txbufferlen)
            {
                itriggered_tx = false;
                tx ~= cast(ubyte)value;
                if (!txdelay)
                    txdelay = txchardelay;
                return;
            }
            assert(0);
        case 0x8:
            break;
        case 0xC:
            // 0 - Reset TX FIFO
            // 1 - Reset RX FIFO
            // 4 - Enable interrupt
            if (value & (1 << 0))
            {
                tx = null;
                txdelay = 0;
            }
            if (value & (1 << 1))
            {
                rx = null;
                waitingforreset = false;
            }
            ienable = (value & (1 << 4)) != 0;
            break;
        default:
            assert(0, "Invalid write to unmapped uart register");
        }
    }
}

class SimpleTimerMemoryMapping : MemoryMapping
{
    uint counter;
    uint cyclecounter;
    uint interval;
    bool timer_triggered;

    this(uint base, uint interval)
    {
        super(base, 0x1000, AddressSpace.data);
        this.interval = interval;
    }

    override void cycle()
    {
        counter++;
        cyclecounter++;
        if (counter == interval)
        {
            counter = 0;
            timer_triggered = true;
        }
    }

    override bool interrupt()
    {
        return timer_triggered;
    }

    override uint read4(uint addr)
    {
        switch (addr - base)
        {
        case 0x0:
            return counter;
        case 0x4:
            return cyclecounter;
        default:
            assert(0, "Invalid read from unmapped uart register");
        }
    }

    override void write4(uint addr, uint value)
    {
        switch (addr - base)
        {
        case 0x0:
            timer_triggered = false;
            break;
        default:
            assert(0, "Invalid write to unmapped timer register");
        }
    }
}

struct Instruction
{
    string name;
    string pattern;
    ulong mask;
    ulong match;

    this(string name, string pattern)
    {
        this.name = name;
        this.pattern = pattern;
        mask = 0;
        match = 0;
        foreach(i; 0..pattern.length)
        {
            auto c = pattern[$-i-1];
            if (c == '0' || c == '1')
                mask |= 1L << i;
            if (c == '1')
                match |= 1L << i;
        }
    }
}

string decodeImmediates(immutable(Instruction)[] insts)
{
    ulong[char] mask;
    ulong[char] base;
    foreach(inst; insts)
    {
        foreach(i, c; inst.pattern)
        {
            auto v = inst.pattern.length - i - 1;
            if (c == '0' || c == '1')
            {
            }
            else if (c in mask)
            {
                mask[c] |= 1LU << v;
                base[c] = min(base[c], v);
            }
            else
            {
                mask[c] = 1LU << v;
                base[c] = v;
            }
        }
    }
    string r;
    foreach(c, m; mask)
    {
        auto b = base[c];
        r ~= "    uint imm_%s = (opc & 0x%X) >> %s;\n".format(c, m, b);
    }
    return r;
}

struct Symbol
{
    uint addr;
    string name;
}

struct RegProxy
{
    Machine m;
    size_t i;

    void opAssign(uint value)
    {
        m.setReg(i, value);
    }
    uint getValue()
    {
        return m.getReg(i);
    }
    alias getValue this;
    @disable this(this);
}

class Machine
{
    uint cycle;
    uint pc;
    MemoryMapping[] mappings;
    MemoryMapping[int] irqMappings;
    bool halted;
    File logfile;
    Symbol[] symbols;

    uint inst_max_bits;
    bool imem_little_endian;
    bool dmem_little_endian;

    bool printargs;
    bool printmem;
    bool printinst;
    UartDataSource debugSocket;
    bool running;
    string debugBuffer;
    bool[uint] breakpoints;

    this(uint inst_max_bits, string imem_little_endian, string dmem_little_endian)
    {
        this.inst_max_bits = inst_max_bits;
        this.imem_little_endian = imem_little_endian == "EL";
        this.dmem_little_endian = dmem_little_endian == "EL";
        //debugSocket = new FileDataSource(File("gdbin.bin", "rb"), File("gdbout.bin", "wb"));
        debugSocket = new SocketDataSource(2159);
        //breakpoints[0xFFFFFFFC] = true;
    }

    void mapMemory(MemoryMapping m)
    {
        foreach(mx; mappings)
            assert(mx.space != m.space || mx.base + mx.length <= m.base || m.base + m.length <= mx.base);
        mappings ~= m;
    }
    void mapIRQ(int irq, MemoryMapping m)
    {
        irqMappings[irq] = m;
    }
    void setPC(uint pc)
    {
        this.pc = pc;
    }
    void setLog(File f)
    {
        logfile = f;
    }
    void addSymbol(Symbol s)
    {
        symbols ~= s;
    }
    string prettySym(uint addr)
    {
        if (!symbols.length)
            return format("%.8X", addr);
        foreach(i, sym; symbols)
        {
            if (sym.addr > addr)
            {
                if (i)
                    return format("(0x%.8X) %s+0x%X", addr, symbols[i-1].name, addr - symbols[i-1].addr);
                break;
            }
        }
        return format("(0x%.8X)", addr);
    }
    bool isMapped(uint addr, int space)
    {
        foreach(m; mappings)
        {
            if (m.space != space && m.space != AddressSpace.both)
                continue;
            if (!m.inRange(addr))
                continue;
            return true;
        }
        return false;
    }
    T load(T, A = T)(uint addr, int space)
    {
        foreach(m; mappings)
        {
            if (m.space != space && m.space != AddressSpace.both)
                continue;
            if (!m.inRange(addr))
                continue;
            assert(!(addr & (A.sizeof-1)), "Alignment error at address 0x%.8X".format(addr));

            static if (T.sizeof == 1) return m.read1(addr);
            else static if (T.sizeof == 2) return m.read2(addr);
            else static if (T.sizeof == 4) return m.read4(addr);
            else static if (T.sizeof == 8) return m.read8(addr);
            else static assert(0);
        }
        assert(0, format("No mapping at address 0x%.8X", addr));
    }
    void store(T, A = T)(uint addr, T data, int space)
    {
        foreach(m; mappings)
        {
            if (m.space != space && m.space != AddressSpace.both)
                continue;
            if (!m.inRange(addr))
                continue;
            assert(!(addr & (A.sizeof-1)), "Alignment error");

            static if (T.sizeof == 1) return m.write1(addr, data);
            else static if (T.sizeof == 2) return m.write2(addr, data);
            else static if (T.sizeof == 4) return m.write4(addr, data);
            else static if (T.sizeof == 8) return m.write8(addr, data);
            else static assert(0);
        }
        assert(0, format("No mapping at address 0x%.8X", addr));
    }
    void step()
    {
        runat(pc);
    }

string sendBuffer;
void gdbSend(in char[] str)
{
    foreach(c; str)
    {
        while (debugSocket.full()) {}
        debugSocket.write(c);
    
    }
    //writeln(str);
    sendBuffer ~= str;
}
void gdbSendChecksum()
{
    // cal from sendBuffer
    auto result = calculate_checksum(sendBuffer[1..$]);
    gdbSend("#%02x".format(result));
    sendBuffer = null;
}


uint calculate_checksum(string input) {

  uint checksum;
  
  foreach(c; input) {
   checksum+=c;
  }
  
  return checksum % 256;
}

void receiveGDBPacket()
{

    while (!debugSocket.empty())
    
        debugBuffer ~= debugSocket.read();
        
        
        
    if (pc in breakpoints && breakpoints[pc] == true && running == true)
    {
        running = false;
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$T05thread:01;");
        gdbSendChecksum();
        //assert(0);
        return;
    }
    
    else if (pc == 0xFFFFFFFC && running == true)
    {
        running = false;
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$T05thread:01;");
        gdbSendChecksum();
        //assert(0);
        return;
    }
        //writeln(debugBuffer);
        //writeln("Hello!");
        //regex for GDB read length addressable memory
    //if (debugBuffer.length && debugBuffer[0] == '$')
    // static read_mem = regex(r"^\$m([0-9A-Fa-f]+),([0-9A-Fa-f]+)#([0-9A-Fa-f]{2})");
    if (debugBuffer.startsWith("$m"))
    {
        auto packet = debugBuffer[2..$];
        auto addr = packet.parse!uint(16);
        
        assert(packet.startsWith(","));
        packet = packet[1..$];
        
        auto length = packet.parse!uint(16);
        
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);

        gdbSend("+");
        sendBuffer = null;
        gdbSend("$");
        foreach(i; 0..length)
        {
            if (isMapped(addr+i,AddressSpace.data)) {
            auto v = load!ubyte(addr + i, AddressSpace.data);
            gdbSend("%02X".format(v));
            }
            else { 
             gdbSend("00");
            }
        }
        gdbSendChecksum();
        debugBuffer = packet;
    }
    
    
    // redoing write to memory
    
    else if (debugBuffer.startsWith("$M"))
    {
        auto packet = debugBuffer[2..$];
        auto addr = packet.parse!uint(16);
        
        assert(packet.startsWith(","));
        packet = packet[1..$];
        
        auto length = packet.parse!uint(16);
        
        assert(packet.startsWith(":"));
        packet = packet[1..$];
        auto data = packet[0..length*2];
        packet = packet[length*2..$];
        
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        foreach(i; 0..length)
        {
            auto v = data[i*2..i*2+2].to!ubyte(16);
            store!ubyte(addr+i,v,AddressSpace.data);
            gdbSend("$%02X".format(v));
        }
        gdbSendChecksum();
        debugBuffer = packet; 
    }
    
    // d query
        else if (debugBuffer.startsWith("$D")) 
        {
        
        auto packet = debugBuffer[2..$];
        
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        
        auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);

        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        gdbSendChecksum();
        debugBuffer = packet;
    
    }
    
    // redoing read general registers
    
    else if (debugBuffer.startsWith("$g"))
    {
        auto packet = debugBuffer[2..$];
        
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        
        auto csum = packet.parse!uint(16);
        
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);

        gdbSend("+");
        sendBuffer = null;
        gdbSend("$");
        foreach(i; 0..73)
        {
            auto v = getRegisterValue(i);
            //writeln(v);
            gdbSend("%08x".format(v));
        }
        gdbSendChecksum();
        debugBuffer = packet;
    }
    
    
    // redoing specific register protocol
    
    else if (debugBuffer.startsWith("$p"))
    {
        auto packet = debugBuffer[2..$];
        auto addr = packet.parse!uint(16);
        
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        
        auto csum = packet.parse!uint(16);
        uint v;
        //writeln(csum);
        //writeln(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        //writeln(calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]));
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        
        v = getRegisterValue(addr);
        
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$%08X".format(v));
        gdbSendChecksum();
        debugBuffer = packet;
    }
    
    else if (debugBuffer.startsWith("$P"))
    {
        //writeln("'", debugBuffer, "'");
        auto packet = debugBuffer[2..$];
        auto addr = packet.parse!uint(16);
        
        assert(packet.startsWith("="));
        packet = packet[1..$];
        auto value = packet.parse!uint(16);
        
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        //writeln(csum);
        //writeln(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        //writeln(calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]));
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);

        setReg(addr, value);
        debugBuffer = packet;
    }
    
    //redo continue instruction
    
    else if (debugBuffer.startsWith("$c"))
    {
        auto packet = debugBuffer[2..$];
        
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        
        auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);

        debugBuffer = packet;
        running = true;
    }

    
    
    // redo + symbol

    else if (debugBuffer.startsWith("+"))
    {
        auto packet = debugBuffer[1..$];
        debugBuffer = packet;
     }
     else if (debugBuffer.startsWith("-"))
    {
        auto packet = debugBuffer[1..$];
        debugBuffer = packet;
     }
    
    
    // vMustReplyEmpty query
    
    else if (debugBuffer.startsWith("$vMustReplyEmpty")) {
        auto packet = debugBuffer[16..$];
         
        assert(packet.startsWith('#'));
        packet = packet[1..$];
         
        auto csum = packet.parse!uint(16);
            
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$");
        gdbSendChecksum();
        debugBuffer = packet;
    
    }
    
    // Hg0 packet
    
    else if (debugBuffer.startsWith("$Hg0")) {
    
         auto packet = debugBuffer[4..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    // X Packet
    //  $X0,0:#1e
    else if (debugBuffer.startsWith("$X")) {
        auto packet = debugBuffer[2..$];
        auto addr = packet.parse!uint(16);
        writefln("addr: %08X",addr);
        assert(packet.startsWith(","));
        packet = packet[1..$];
        
        auto length = packet.parse!uint(16);
        writefln("length: %08X",length);
        assert(packet.startsWith(":"));
        packet = packet[1..$];
        // writefln("plen: %s",packet.length);
        // writefln("p: %(%02X %)",cast(ubyte[])packet);
        ubyte[4096] data;
        size_t c = 0;
        while (c < length)
        {
            if (packet[0] == 0x7D)
            {
                data[c] = packet[1] ^ 0x20;
                packet = packet[2..$];
            }
            else
            {
                data[c] = packet[0];
                packet = packet[1..$];
            }
            c++;
        }
        
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        foreach(i; 0..length)
        {
            auto v = data[i];
            store!ubyte(addr+i,v,AddressSpace.data);
        }
        gdbSendChecksum();
        debugBuffer = packet; 
    }
    
    // Hg1 packet
    
    else if (debugBuffer.startsWith("$Hg1")) {
    
         auto packet = debugBuffer[4..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    // hc- packet
    
    else if (debugBuffer.startsWith("$Hc-")) {
    
         auto packet = debugBuffer[4..$];
         assert(packet.startsWith("1"));
         packet = packet[1..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    // hc0 packet
    
    else if (debugBuffer.startsWith("$Hc0")) {
    
         auto packet = debugBuffer[4..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    // qTStatus
    
    else if (debugBuffer.startsWith("$qTStatus")) {
    
         auto packet = debugBuffer[9..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
     //qtfv
    
     else if (debugBuffer.startsWith("$qTfV")) {
    
         auto packet = debugBuffer[5..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    // ? query 
    
     else if (debugBuffer.startsWith("$?")) {
    
         auto packet = debugBuffer[2..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$T05thread:01;");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    // qfThreadInfo query
    
     else if (debugBuffer.startsWith("$qfThreadInfo")) {
    
         auto packet = debugBuffer[13..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$m1");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    // qsThreadInfo
    
     else if (debugBuffer.startsWith("$qsThreadInfo")) {
    
         auto packet = debugBuffer[13..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$l");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    // qAttached query
     else if (debugBuffer.startsWith("$qAttached")) {
    
         auto packet = debugBuffer[10..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$1");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    
    // qsymbol query
    
    
    else if (debugBuffer.startsWith("$qSymbol::")) {
    
         auto packet = debugBuffer[10..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    
    
    // qoffsets query
    
    else if (debugBuffer.startsWith("$qOffsets")) {
    
         auto packet = debugBuffer[9..$];
         assert(packet.startsWith("#"));
         packet = packet[1..$];
         auto csum = packet.parse!uint(16);
        
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$");
        gdbSendChecksum();
        debugBuffer = packet;
           
    
    }
    
    // z0 query -- remove software breakpoint
    else if (debugBuffer.startsWith("$z0")) {
    
        auto packet = debugBuffer[3..$];
        assert(packet.startsWith(","));
        packet = packet[1..$];
        auto addr = packet.parse!uint(16);
        assert(packet.startsWith(","));
        packet = packet[1..$];
        auto type = packet.parse!uint(16);
        assert(type == 4);
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        breakpoints[addr] = false;
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        gdbSendChecksum();
        logfile.writefln("printing at remove breakpoint addr: %08X", addr);
        debugBuffer = packet;
        
    }
    
    
    // Z0 query -- set software breakpoint
    
    else if (debugBuffer.startsWith("$Z0")) {
    
        auto packet = debugBuffer[3..$];
        assert(packet.startsWith(","));
        packet = packet[1..$];
        auto addr = packet.parse!uint(16);
        assert(packet.startsWith(","));
        packet = packet[1..$];
        auto type = packet.parse!uint(16);
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        breakpoints[addr] = true;
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$OK");
        gdbSendChecksum();
        logfile.writefln("printing at set breakpoint addr: %08X", addr);
        debugBuffer = packet;
        
    }
    
    // vCont query
    
    else if (debugBuffer.startsWith("$vCont?")) {
    
        auto packet = debugBuffer[7..$];
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$vCont;c;C;s;S");
        gdbSendChecksum();
        debugBuffer = packet;
        
    }
    
    // vKill query
    
    else if (debugBuffer.startsWith("$vKill")) {
    
        auto packet = debugBuffer[6..$];
        assert(packet.startsWith(";"));
        packet = packet[1..$];
        auto pid = packet.parse!uint(16);
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$");
        gdbSendChecksum();
        debugBuffer = packet;
        
    }
    
    // k query
    
    else if (debugBuffer.startsWith("$k")) {
    
        auto packet = debugBuffer[2..$];
        assert(packet.startsWith("#"));
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        gdbSend("+");
        halted = true;
        debugBuffer = packet;
        
    }
    
    // vContContinue query
    
        else if (debugBuffer.startsWith("$vCont;c")) {
    
        auto packet = debugBuffer[8..$];
        if (packet.startsWith(":1")) {
            packet = packet[2..$];
        }
        assert(packet.startsWith("#"),debugBuffer);
        
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        //gdbSend("+");
        //sendBuffer = null;
        //gdbSend("$");
        debugBuffer = packet;
        running = true;
    }
    
    // qsupported query
    else if (debugBuffer.startsWith("$qSupported"))
    {
        auto packet = debugBuffer[11..$];       
        assert(packet.startsWith(":"));
        packet = packet[1..$];
        
        bool[string] features;
        while(!packet.startsWith('#')) {
          string returnString;
           while(!packet.startsWith('+')) {
              
            returnString ~= packet[0];
            packet = packet[1..$];
           }
           assert(packet.startsWith('+'));
           packet = packet[1..$];
           features[returnString] = true;
            if(packet.startsWith('#')) {
                break;
           }
           assert(packet.startsWith(';'),packet);
           packet = packet[1..$];
        }
        packet = packet[1..$];
        auto csum = packet.parse!uint(16);
        auto csum_valid = calculate_checksum(debugBuffer[1..packet.ptr - debugBuffer.ptr - 3]);
        assert(csum_valid == csum);
        //writeln(features);
        gdbSend("+");
        sendBuffer = null;
        gdbSend("$PacketSize=1000");
        gdbSendChecksum();
        debugBuffer = packet;
    }
    
     else if (debugBuffer.length)
    {
        assert(0, debugBuffer);
    }

}

    uint getRegisterValue(uint addr)
    {
        assert(0);
    }
    void waitForDebugger() 
    {
      do {
     
     receiveGDBPacket();
      }  while (!running);
      
    }
    void runat(uint addr)
    {
        foreach(m; mappings)
            m.cycle();

        uint irqs;
        foreach(irq, m; irqMappings)
            irqs |= m.interrupt() << irq;
        if (handleExceptions(irqs))
            return;

        bool exception;
        auto paddr = translateFetchAddress(addr, exception);
        if (exception)
            return;

        auto opc = getInstruction(paddr);
        auto instlist = getInstructionList();
        scope(failure) stderr.writefln("At 0x%.8X", addr);

        foreach(i, inst; instlist)
        {
            assert(inst.pattern.length <= inst_max_bits);
            if ((opc & inst.mask) == inst.match)
            {
                if (printinst)
                    printInstruction(inst.name, opc, addr, null);
                runInstruction(inst.name, opc);
                return;
            }
        }
        assert(0, "Unknown instruction " ~ format("%.*b", inst_max_bits, opc));
    }
    void doMemory(ref ulong rd, uint addr, bool doLoad)
    {
        if (doLoad)
        {
            rd = load!(ulong, uint)(addr, AddressSpace.data);
            if (printmem)
                logfile.writefln("# Read %016X size 8 from %08X", rd, addr);
        }
        else
        {
            store!(ulong, uint)(addr, rd, AddressSpace.data);
            if (printmem)
                logfile.writefln("# Write %016X size 8 to %08X", rd, addr);
        }
    }
    uint doMemoryLoad(uint addr, uint size, bool extend)
    {
        assert(size == 1 || size == 2 || size == 4);
        uint rd;
        switch(size)
        {
        case 1:
            if (extend)
                rd = cast(int)load!byte(addr, AddressSpace.data);
            else
                rd = cast(uint)load!ubyte(addr, AddressSpace.data);
            break;
        case 2:
            if (extend)
                rd = cast(int)load!short(addr, AddressSpace.data);
            else
                rd = cast(uint)load!ushort(addr, AddressSpace.data);
            break;
        case 4:
            if (extend)
                rd = cast(int)load!int(addr, AddressSpace.data);
            else
                rd = cast(uint)load!uint(addr, AddressSpace.data);
            break;
        default:
            assert(0);
        }
        if (printmem)
            logfile.writefln("# Read %08X size %d from %08X", rd, size, addr);
        return rd;
    }
    void doMemoryStore(uint rd, uint addr, uint size)
    {
        assert(size == 1 || size == 2 || size == 4);
        switch(size)
        {
        case 1:
            store(addr, cast(ubyte)rd, AddressSpace.data);
            break;
        case 2:
            store(addr, cast(ushort)rd, AddressSpace.data);
            break;
        case 4:
            store(addr, cast(uint)rd, AddressSpace.data);
            break;
        default:
            assert(0);
        }
        if (printmem)
            logfile.writefln("# Write %08X size %d to %08X", rd, size, addr);
    }
    void doRMW(uint rd, uint addr, uint mask)
    {
        uint t = load!uint(addr, AddressSpace.data);
        t = (t & ~mask) | (rd & mask);
        store(addr, t, AddressSpace.data);
        if (printmem)
            logfile.writefln("# Write %08X size 4 to %08X mask 0x%.8X", rd, addr, mask);
    }
    uint translateFetchAddress(uint vaddr, out bool exception)
    {
        return vaddr;
    }
    abstract ulong getInstruction(uint pc);
    abstract immutable(Instruction)[] getInstructionList();
    bool handleExceptions(uint irqs)
    {
        return false;
    }
    abstract void printInstruction(string name, ulong opc, uint addr, uint[char] args);
    abstract void runInstruction(string name, ulong opc);
    abstract uint getReg(size_t i);
    abstract void setReg(size_t i, uint value);
}
