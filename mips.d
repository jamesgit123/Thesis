
import std.conv;
import std.stdio;
import std.string;

import machine;

immutable Instruction[] mipsinst =
[
    Instruction("add",         "000000ssssstttttddddd00000100000"),
    Instruction("addi",        "001000ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("addiu",       "001001ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("addu",        "000000ssssstttttddddd00000100001"),
    Instruction("and",         "000000ssssstttttddddd00000100100"),
    Instruction("andi",        "001100ssssstttttuuuuuuuuuuuuuuuu"),
    Instruction("beq",         "000100ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("beql",        "010100ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("bgez",        "000001sssss00001iiiiiiiiiiiiiiii"),
    Instruction("bgezal",      "000001sssss10001iiiiiiiiiiiiiiii"),
    Instruction("bgezall",     "000001sssss10011iiiiiiiiiiiiiiii"),
    Instruction("bgezl",       "000001sssss00011iiiiiiiiiiiiiiii"),
    Instruction("bgtz",        "000111sssss00000iiiiiiiiiiiiiiii"),
    Instruction("bgtzl",       "010111sssss00000iiiiiiiiiiiiiiii"),
    Instruction("blez",        "000110sssss00000iiiiiiiiiiiiiiii"),
    Instruction("blezl",       "010110sssss00000iiiiiiiiiiiiiiii"),
    Instruction("bltz",        "000001sssss00000iiiiiiiiiiiiiiii"),
    Instruction("bltzal",      "000001sssss10000iiiiiiiiiiiiiiii"),
    Instruction("bltzall",     "000001sssss10010iiiiiiiiiiiiiiii"),
    Instruction("bltzl",       "000001sssss00010iiiiiiiiiiiiiiii"),
    Instruction("bne",         "000101ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("bnel",        "010101ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("break",       "000000cccccccccccccccccccc001101"),
    Instruction("copz",        "0100zzffffffffffffffffffffffffff"),
    Instruction("dadd",        "000000ssssstttttddddd00000101100"),
    Instruction("daddi",       "011000ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("daddiu",      "011001ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("daddu",       "000000ssssstttttddddd00000101101"),
    Instruction("ddiv",        "000000sssssttttt0000000000011110"),
    Instruction("ddivu",       "000000sssssttttt0000000000011111"),
    Instruction("div",         "000000sssssttttt0000000000011010"),
    Instruction("divu",        "000000sssssttttt0000000000011011"),
    Instruction("dmult",       "000000sssssttttt0000000000011100"),
    Instruction("dmultu",      "000000sssssttttt0000000000011101"),
    Instruction("dsll",        "00000000000tttttdddddaaaaa111000"),
    Instruction("dsll32",      "00000000000tttttdddddaaaaa111100"),
    Instruction("dsllv",       "000000ssssstttttddddd00000010100"),
    Instruction("dsra",        "00000000000tttttdddddaaaaa111011"),
    Instruction("dsra32",      "00000000000tttttdddddaaaaa111111"),
    Instruction("dsrav",       "000000ssssstttttddddd00000010111"),
    Instruction("dsrl",        "00000000000tttttdddddaaaaa111010"),
    Instruction("dsrl32",      "00000000000tttttdddddaaaaa111110"),
    Instruction("dsrlv",       "000000ssssstttttddddd00000010110"),
    Instruction("dsub",        "000000ssssstttttddddd00000101110"),
    Instruction("dsubu",       "000000ssssstttttddddd00000101111"),
    Instruction("j",           "000010jjjjjjjjjjjjjjjjjjjjjjjjjj"),
    Instruction("jalr",        "000000sssss00000ddddd00000001001"),
    Instruction("jal",         "000011jjjjjjjjjjjjjjjjjjjjjjjjjj"),
    Instruction("jr",          "000000sssss000000000000000001000"),
    Instruction("lb",          "100000ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("lbu",         "100100ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("ld",          "110111ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("ldcz",        "1101zzssssstttttiiiiiiiiiiiiiiii"),
    Instruction("ldl",         "011010ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("ldr",         "011011ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("lh",          "100001ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("lhu",         "100101ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("ll",          "110000ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("lld",         "110100ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("lui",         "00111100000tttttiiiiiiiiiiiiiiii"),
    Instruction("lw",          "100011ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("lwcz",        "1100zzssssstttttiiiiiiiiiiiiiiii"),
    Instruction("lwl",         "100010ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("lwr",         "100110ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("lwu",         "100111ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("mfhi",        "0000000000000000ddddd00000010000"),
    Instruction("mflo",        "0000000000000000ddddd00000010010"),
    Instruction("movn",        "000000ssssstttttddddd00000001011"),
    Instruction("movz",        "000000ssssstttttddddd00000001010"),
    Instruction("mthi",        "000000sssss000000000000000010001"),
    Instruction("mtlo",        "000000sssss000000000000000010011"),
    Instruction("mult",        "000000sssssttttt0000000000011000"),
    Instruction("multu",       "000000sssssttttt0000000000011001"),
    Instruction("nor",         "000000ssssstttttddddd00000100111"),
    Instruction("or",          "000000ssssstttttddddd00000100101"),
    Instruction("ori",         "001101ssssstttttuuuuuuuuuuuuuuuu"),
    Instruction("pref",        "110011ssssshhhhhiiiiiiiiiiiiiiii"),
    Instruction("sb",          "101000ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("sc",          "111000ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("scd",         "111100ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("sdcz",        "1111zzssssstttttiiiiiiiiiiiiiiii"),
    Instruction("sdl",         "101100ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("sdr",         "101101ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("sh",          "101001ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("sll",         "00000000000tttttdddddaaaaa000000"),
    Instruction("sllv",        "000000ssssstttttddddd00000000100"),
    Instruction("slt",         "000000ssssstttttddddd00000101010"),
    Instruction("slti",        "001010ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("sltiu",       "001011ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("sltu",        "000000ssssstttttddddd00000101011"),
    Instruction("sra",         "00000000000tttttdddddaaaaa000011"),
    Instruction("srav",        "000000ssssstttttddddd00000000111"),
    Instruction("srl",         "00000000000tttttdddddaaaaa000010"),
    Instruction("srlv",        "000000ssssstttttddddd00000000110"),
    Instruction("sub",         "000000ssssstttttddddd00000100010"),
    Instruction("subu",        "000000ssssstttttddddd00000100011"),
    Instruction("sw",          "101011ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("stcz",        "1110zzssssstttttiiiiiiiiiiiiiiii"),
    Instruction("swl",         "101010ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("swr",         "101110ssssstttttiiiiiiiiiiiiiiii"),
    Instruction("sync",        "000000000000000000000kkkkk001111"),
    Instruction("syscall",     "000000cccccccccccccccccccc001100"),
    Instruction("teq",         "000000ssssstttttxxxxxxxxxx110100"),
    Instruction("teqi",        "000001sssss01100iiiiiiiiiiiiiiii"),
    Instruction("tge",         "000000ssssstttttxxxxxxxxxx110000"),
    Instruction("tgei",        "000001sssss01000iiiiiiiiiiiiiiii"),
    Instruction("tgeiu",       "000001sssss01001iiiiiiiiiiiiiiii"),
    Instruction("tgeu",        "000000ssssstttttxxxxxxxxxx110001"),
    Instruction("tlt",         "000000ssssstttttxxxxxxxxxx110010"),
    Instruction("tlti",        "000001sssss01010iiiiiiiiiiiiiiii"),
    Instruction("tltiu",       "000001sssss01011iiiiiiiiiiiiiiii"),
    Instruction("tltu",        "000000ssssstttttxxxxxxxxxx110011"),
    Instruction("tne",         "000000ssssstttttxxxxxxxxxx110110"),
    Instruction("tnei",        "000001sssss01110iiiiiiiiiiiiiiii"),
    Instruction("xor",         "000000ssssstttttddddd00000100110"),
    Instruction("xori",        "001110ssssstttttuuuuuuuuuuuuuuuu"),
];

string[] regname =
[
    "zero",
    "at",
    "v0", "v1",
    "a0", "a1", "a2", "a3",
    "t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7",
    "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
    "t8", "t9",
    "k0", "k1",
    "gp",
    "sp",
    "fp",
    "ra",
];

static this()
{
    registerMachine("mips1", () => new MipsMachine("EB"));
    registerMachine("mipsel1", () => new MipsMachine("EL"));
}

class MipsMachine : Machine
{
    uint[32] regs;
    uint hi, lo;

    void delegate() delay;
    void delegate() newdelay;

    this(string endian)
    {
        super(32, "EB", endian);
    }
    override ulong getInstruction(uint addr)
    {
        return load!uint(addr, AddressSpace.instruction);
    }
    override immutable(Instruction)[] getInstructionList()
    {
        return mipsinst;
    }
    override uint getReg(size_t i)
    {
        return regs[i];
    }
    override void setReg(size_t i, uint value)
    {
        if (i)
        {
            regs[i] = value;
            logfile.writefln("# Write(0) %08X to R%d", value, i);
        }
    }
    
    override uint getRegisterValue(uint addr)
    {
        if ( addr < 32)
            return getReg(addr);
        else if (addr == 37)
            return pc;
        else if (addr == 32)
            return 0x00400004;
        else if (addr == 33)
            return hi;
        else if (addr == 34)
            return lo;
        else if (addr == 71) {
            return 0x00739300;
        }
        else if (addr >= 35 && addr <= 36)
            return 0;
        else if (addr >= 38 && addr <= 89)
            return 0;
        else
            assert(0);
    }

    override void printInstruction(string name, ulong opc, uint addr, uint[char] args)
    {
        logfile.writef("# Inst %s %08X %-7s", prettySym(addr), opc, name);
        // if ('d' in args) logfile.writef(" %s(0x%.8X)", regname[args['d']], regs[args['d']]);
        // if ('t' in args) logfile.writef(" %s(0x%.8X)", regname[args['t']], regs[args['t']]);
        // if ('s' in args) logfile.writef(" %s(0x%.8X)", regname[args['s']], regs[args['s']]);
        // if ('i' in args) logfile.writef(" i+%d(0x%.8X)", args['i'], cast(int)cast(short)args['i']);
        // if ('u' in args) logfile.writef(" u+%d(0x%.8X)", args['u'], args['u']);
        // if ('j' in args) logfile.writef(" j+%d(0x%.8X)", args['j'], args['j']);
        // if ('a' in args) logfile.writef(" a+%d(0x%.8X)", args['a'], args['a']);
        logfile.writeln();
    }
    override void runInstruction(string name, ulong opc)
    {
        newdelay = null;
        if (halted) return;

        // pragma(msg, decodeImmediates(mipsinst));
        mixin(decodeImmediates(mipsinst));

        auto rs = RegProxy(this, imm_s);
        auto rt = RegProxy(this, imm_t);
        auto rd = RegProxy(this, imm_d);
        uint imm16 = cast(int)cast(short)(imm_i);
        auto bimm16 = imm16 << 2;
        uint uimm16 = imm_u;
        uint imm26 = imm_j << 2;
        uint shamt = imm_a;

        switch(name)
        {
        case "addu":   rd = rs + rt;    pc += 4; break;
        case "and":    rd = rs & rt;    pc += 4; break;
        case "or":     rd = rs | rt;    pc += 4; break;
        case "nor":    rd = ~(rs | rt); pc += 4; break;
        case "subu":   rd = rs - rt;    pc += 4; break;
        case "xor":    rd = rs ^ rt;    pc += 4; break;

        case "addiu":  rt = rs + imm16;  pc += 4; break;
        case "andi":   rt = rs & uimm16; pc += 4; break;
        case "ori":    rt = rs | uimm16; pc += 4; break;
        case "xori":   rt = rs ^ uimm16; pc += 4; break;

        case "beq":    doBranchIf(rs == rt, bimm16); pc += 4; break;
        case "bne":    doBranchIf(rs != rt, bimm16); pc += 4; break;

        case "bgez":   doBranchIf(cast(int)rs >= 0, bimm16); pc += 4; break;
        case "bgtz":   doBranchIf(cast(int)rs >  0, bimm16); pc += 4; break;
        case "blez":   doBranchIf(cast(int)rs <= 0, bimm16); pc += 4; break;
        case "bltz":   doBranchIf(cast(int)rs <  0, bimm16); pc += 4; break;

        case "bgezal": doBranchIf(cast(int)rs >= 0, bimm16, true); pc += 4; break;
        case "bltzal": doBranchIf(cast(int)rs <  0, bimm16, true); pc += 4; break;

        case "divu":   lo = rs / rt; hi = rs % rt; pc += 4; break;

        case "mult":   ulong t = cast(long) rs * cast(long) rt; lo = cast(uint)t; hi = t >> 32; pc += 4; break;
        case "multu":  ulong t = cast(ulong)rs * cast(ulong)rt; lo = cast(uint)t; hi = t >> 32; pc += 4; break;

        case "mflo":   rd = lo; pc += 4; break;
        case "mfhi":   rd = hi; pc += 4; break;

        case "break":  halted = true; break;
        case "nop":    pc += 4; break;
        case "lui":    rt = imm16 << 16; pc += 4; break;
        case "syscall":regs[26] = pc + 4; pc = 0x60; break;

        case "j":                         doBranch((pc & 0xF0000000) | imm26); pc += 4; break;
        case "jr":                        doBranch(rs);                       pc += 4; break;
        case "jal":    regs[31] = pc + 8; doBranch((pc & 0xF0000000) | imm26); pc += 4; break;
        case "jalr":   regs[31] = pc + 8; doBranch(rs);                       pc += 4; break;

        case "lb":     rt = doMemoryLoad(rs + imm16, 1, true);  pc += 4; break;
        case "lbu":    rt = doMemoryLoad(rs + imm16, 1, false); pc += 4; break;
        case "lh":     rt = doMemoryLoad(rs + imm16, 2, true);  pc += 4; break;
        case "lhu":    rt = doMemoryLoad(rs + imm16, 2, false); pc += 4; break;
        case "lw":     rt = doMemoryLoad(rs + imm16, 4, false); pc += 4; break;

        case "lwl":    doMemoryLeftRight(rt, rs + imm16, true,  true);  pc += 4; break;
        case "lwr":    doMemoryLeftRight(rt, rs + imm16, true,  false); pc += 4; break;

        case "sb":     doMemoryStore(rt, rs + imm16, 1); pc += 4; break;
        case "sh":     doMemoryStore(rt, rs + imm16, 2); pc += 4; break;
        case "sw":     doMemoryStore(rt, rs + imm16, 4); pc += 4; break;

        case "swl":    doMemoryLeftRight(rt, rs + imm16, false, true);  pc += 4; break;
        case "swr":    doMemoryLeftRight(rt, rs + imm16, false, false); pc += 4; break;

        case "sll":    rd = cast(uint)rt << shamt; pc += 4; break;
        case "sra":    rd = cast(int) rt >> shamt; pc += 4; break;
        case "srl":    rd = cast(uint)rt >> shamt; pc += 4; break;

        case "sllv":   rd = cast(uint)rt << rs; pc += 4; break;
        case "srav":   rd = cast(int) rt >> rs; pc += 4; break;
        case "srlv":   rd = cast(uint)rt >> rs; pc += 4; break;

        case "slt":    rd = cast(int) rs < cast(int) rt;   pc += 4; break;
        case "sltu":   rd = cast(uint)rs < cast(uint)rt;   pc += 4; break;

        case "slti":   rt = cast(int) rs < cast(int) imm16; pc += 4; break;
        case "sltiu":  rt = cast(uint)rs < cast(uint)imm16; pc += 4; break;

        default:
            assert(0, "Unhandled instruction: " ~ name);
        }

        regs[0] = 0;
        if (delay)
            delay();
        delay = newdelay;
        //if (pc == 0xFFFFFFFC)
            //running = false;
    }
    void doBranch(uint a)
    {
        newdelay = () { pc = a; };
    }
    void doBranchIf(bool cond, uint a, bool link = false)
    {
        auto npc = pc + a + 4;
        auto linkret = pc + 8;
        if (cond && link)
            newdelay = () { regs[31] = linkret; pc = npc; };
        else if (cond)
            newdelay = () { pc = npc; };
    }
    void doMemoryLeftRight(ref RegProxy rd, uint addr, bool doLoad, bool left)
    {
        if (dmem_little_endian)
        {
            if (doLoad)
            {
                uint t = doMemoryLoad(addr & ~3, 4, false);
                if (left)
                {
                    switch(addr & 3)
                    {
                    case 0: rd = (t << 24 & 0xFF000000) | (rd & 0x00FFFFFF); break;
                    case 1: rd = (t << 16 & 0xFFFF0000) | (rd & 0x0000FFFF); break;
                    case 2: rd = (t <<  8 & 0xFFFFFF00) | (rd & 0x000000FF); break;
                    case 3: rd = (t <<  0 & 0xFFFFFFFF) | (rd & 0x00000000); break;
                    default: assert(0);
                    }
                }
                else
                {
                    switch(addr & 3)
                    {
                    case 0: rd = (t >>  0 & 0xFFFFFFFF) | (rd & 0x00000000); break;
                    case 1: rd = (t >>  8 & 0x00FFFFFF) | (rd & 0xFF000000); break;
                    case 2: rd = (t >> 16 & 0x0000FFFF) | (rd & 0xFFFF0000); break;
                    case 3: rd = (t >> 24 & 0x000000FF) | (rd & 0xFFFFFF00); break;
                    default: assert(0);
                    }
                }
            }
            else
            {
                if (left)
                {
                    switch(addr & 3)
                    {
                    case 0: doRMW(rd >> 24, addr & ~3, 0x000000FF); break;
                    case 1: doRMW(rd >> 16, addr & ~3, 0x0000FFFF); break;
                    case 2: doRMW(rd >>  8, addr & ~3, 0x00FFFFFF); break;
                    case 3: doRMW(rd >>  0, addr & ~3, 0xFFFFFFFF); break;
                    default: assert(0);
                    }
                }
                else
                {
                    switch(addr & 3)
                    {
                    case 0: doRMW(rd <<  0, addr & ~3, 0xFFFFFFFF); break;
                    case 1: doRMW(rd <<  8, addr & ~3, 0xFFFFFF00); break;
                    case 2: doRMW(rd << 16, addr & ~3, 0xFFFF0000); break;
                    case 3: doRMW(rd << 24, addr & ~3, 0xFF000000); break;
                    default: assert(0);
                    }
                }
            }
        }
        else
        {
            if (doLoad)
            {
                uint t = doMemoryLoad(addr & ~3, 4, false);
                if (left)
                {
                    switch(addr & 3)
                    {
                    case 0: rd = (t <<  0 & 0xFFFFFFFF) | (rd & 0x00000000); break;
                    case 1: rd = (t <<  8 & 0xFFFFFF00) | (rd & 0x000000FF); break;
                    case 2: rd = (t << 16 & 0xFFFF0000) | (rd & 0x0000FFFF); break;
                    case 3: rd = (t << 24 & 0xFF000000) | (rd & 0x00FFFFFF); break;
                    default: assert(0);
                    }
                }
                else
                {
                    switch(addr & 3)
                    {
                    case 0: rd = (t >> 24 & 0x000000FF) | (rd & 0xFFFFFF00); break;
                    case 1: rd = (t >> 16 & 0x0000FFFF) | (rd & 0xFFFF0000); break;
                    case 2: rd = (t >>  8 & 0x00FFFFFF) | (rd & 0xFF000000); break;
                    case 3: rd = (t >>  0 & 0xFFFFFFFF) | (rd & 0x00000000); break;
                    default: assert(0);
                    }
                }
            }
            else
            {
                if (left)
                {
                    switch(addr & 3)
                    {
                    case 0: doRMW(rd >>  0, addr & ~3, 0xFFFFFFFF); break;
                    case 1: doRMW(rd >>  8, addr & ~3, 0x00FFFFFF); break;
                    case 2: doRMW(rd >> 16, addr & ~3, 0x0000FFFF); break;
                    case 3: doRMW(rd >> 24, addr & ~3, 0x000000FF); break;
                    default: assert(0);
                    }
                }
                else
                {
                    switch(addr & 3)
                    {
                    case 0: doRMW(rd << 24, addr & ~3, 0xFF000000); break;
                    case 1: doRMW(rd << 16, addr & ~3, 0xFFFF0000); break;
                    case 2: doRMW(rd <<  8, addr & ~3, 0xFFFFFF00); break;
                    case 3: doRMW(rd <<  0, addr & ~3, 0xFFFFFFFF); break;
                    default: assert(0);
                    }
                }
            }
        }
    }
}
