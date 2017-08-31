import cpu;
import memory;
import std.stdio;
import std.string;

immutable string[256] opcode_fmt = [
    // 0x00 ~ 0x0F
    "nop", "ld bc,$%04x", "ld (bc), a", "inc bc", "inc b", "dec b", "ld b,$%02x", "rlca",
    "add ($%04x),sp", "add hl,bc", "ld a,(bc)", "dec bc", "inc c", "dec c", "ld c,$%02x", "rrca",
    // 0x10 ~ 0x1F
    "stop", "ld de,$%04x", "ld (de),a", "inc de", "inc d", "dec d", "ld d,$%02x", "rla",
    "jr %d", "add hl,de", "ld a,(de)", "dec de", "inc e", "dec e", "ld e,$%02x", "rra",
    // 0x20 ~ 0x2F
    "jr nz %d", "ld hl,$%04x", "ldi (hl),a", "inc hl", "inc h", "dec h", "ld h,$%02x", "daa",
    "jr z %d", "add hl,hl", "ldi a,(hl)", "dec hl", "inc l", "dec l", "ld l,$%02x", "cpl",
    // 0x30 ~ 0x3F
    "jr nc %d", "ld sp,$%04x", "ldd (hl),a", "inc sp", "inc (hl)", "dec (hl)", "ld (hl),$%02x", "scf",
    "jr c %d", "add hl,sp", "ldd a,(hl)", "dec sp", "inc a", "dec a", "ld a,$%02x", "ccf",
    // 0x40 ~ 0x4F
    "ld b,b", "ld b,c", "ld b,d", "ld b,e", "ld b,h", "ld b,l", "ld b,(hl)", "ld b,a",
    "ld c,b", "ld c,c", "ld c,d", "ld c,e", "ld c,h", "ld c,l", "ld c,(hl)", "ld c,a",
    // 0x50 ~ 0x5F
    "ld d,b", "ld d,c", "ld d,d", "ld d,e", "ld d,h", "ld d,l", "ld d,(hl)", "ld d,a",
    "ld e,b", "ld e,c", "ld e,d", "ld e,e", "ld e,h", "ld e,l", "ld e,(hl)", "ld e,a",
    // 0x60 ~ 0x6F
    "ld h,b", "ld h,c", "ld h,d", "ld h,e", "ld h,h", "ld h,l", "ld h,(hl)", "ld h,a",
    "ld l,b", "ld l,c", "ld l,d", "ld l,e", "ld l,h", "ld l,l", "ld l,(hl)", "ld l,a",
    // 0x70 ~ 0x7F
    "ld (hl),b", "ld (hl),c", "ld (hl),d", "ld (hl),e", "ld (hl),h", "ld (hl),l", "ld (hl),(hl)", "ld (hl),a",
    "ld a,b", "ld a,c", "ld a,d", "ld a,e", "ld a,h", "ld a,l", "ld a,(hl)", "ld a,a",
    // 0x80 ~ 0x8F
    "add a,b", "add a,c", "add a,d", "add a,e", "add a,h", "add a,l", "add a,(hl)",
    "add a,a", "adc a,b", "adc a,c", "adc a,d", "adc a,e", "adc a,h", "adc a,l", "adc a,(hl)", "adc a,a",
    // 0x90 ~ 0x9F
    "sub a,b", "sub a,c", "sub a,d", "sub a,e", "sub a,h", "sub a,l", "sub a,(hl)", "sub a,a",
    "sbc a,b", "sbc a,c", "sbc a,d", "sbc a,e", "sbc a,h", "sbc a,l", "sbc a,(hl)", "sbc a,a",
    // 0xA0 ~ 0xAF
    "and a,b", "and a,c", "and a,d", "and a,e", "and a,h", "and a,l", "and a,(hl)", "and a,a",
    "xor a,b", "xor a,c", "xor a,d", "xor a,e", "xor a,h", "xor a,l", "xor a,(hl)", "xor a,a",
    // 0xB0 ~ 0xBF
    "or a,b", "or a,c", "or a,d", "or a,e", "or a,h", "or a,l", "or a,(hl)", "or a,a",
    "cp a,b", "cp a,c", "cp a,d", "cp a,e", "cp a,h", "cp a,l", "cp a,(hl)", "cp a,a",
    // 0xC0 ~ 0xCF
    "ret nz", "pop bc", "jp nz $%04x", "jp $%04x", "call nz $%04x", "push bc", "add a,$%02x", "rst 00",
    "ret z", "ret", "jp z $%04x", "[CB]", "call z $%04x", "call $%04x", "adc a,$%02x", "rst 08",
    // 0xD0 ~ 0xDF
    "ret nc", "pop de", "jp nc $%04x", "[D3]", "call nc $%04x", "push de", "sub $%02x", "rst 10",
    "ret c", "reti", "jp c $%04x", "[DB]", "call c $%04x", "[DD]", "sbc a,$%02x", "rst 18",
    // 0xE0 ~ 0xEF
    "ldh ($ff%02x),a", "pop hl", "ld (c),a", "[E3]", "[E4]", "push hl", "and $%02x", "rst 20",
    "add sp,$%02x", "jp hl", "ld ($%04x),a", "[EB]", "[EC]", "[ED]", "xor $%02x", "rst 28",
    // 0xF0 ~ 0xFF
    "ldh a,($ff%02x)", "pop af", "ld a,(c)", "di", "[F4]", "push af", "or $%02x", "rst 30",
    "ld hl,sp+$%02x", "ld sp,hl", "ld a,(%04x)", "ei", "[FC]", "[FD]", "cp $%02x", "rst 38"
];

immutable ubyte[256] opcode_len = [
    1, 3, 1, 1, 1, 1, 2, 1, 3, 1, 1, 1, 1, 1, 2, 1,    // 0x00 ~ 0x0F
    2, 3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1,    // 0x10 ~ 0x1F
    2, 3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1,    // 0x20 ~ 0x2F
    2, 3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1,    // 0x30 ~ 0x3F

    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,    // 0x40 ~ 0x4F
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,    // 0x50 ~ 0x5F
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,    // 0x60 ~ 0x6F
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,    // 0x70 ~ 0x7F
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,    // 0x80 ~ 0x8F
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,    // 0x90 ~ 0x9F
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,    // 0xA0 ~ 0xAF
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,    // 0xB0 ~ 0xBF

    1, 1, 3, 3, 3, 1, 2, 1, 1, 1, 3, 2, 3, 3, 2, 1,    // 0xC0 ~ 0xCF
    1, 1, 3, 1, 3, 1, 2, 1, 1, 1, 3, 1, 3, 1, 2, 1,    // 0xD0 ~ 0xDF
    2, 1, 2, 1, 1, 1, 2, 1, 2, 1, 3, 1, 1, 1, 2, 1,    // 0xE0 ~ 0xEF
    2, 1, 2, 1, 1, 1, 2, 1, 2, 1, 3, 1, 1, 1, 2, 1     // 0xF0 ~ 0xFF
];

immutable string[256] cbext_asm = [
    "rlc b", "rlc c", "rlc d", "rlc e", "rlc h", "rlc l", "rlc (hl)", "rlc a",
    "rrc b", "rrc c", "rrc d", "rrc e", "rrc h", "rrc l", "rrc (hl)", "rrc a",

    "rl b", "rl c", "rl d", "rl e", "rl h", "rl l", "rl (hl)", "rl a",
    "rr b", "rr c", "rr d", "rr e", "rr h", "rr l", "rr (hl)", "rr a",

    "sla b", "sla c", "sla d", "sla e", "sla h", "sla l", "sla (hl)", "sla a",
    "sra b", "sra c", "sra d", "sra e", "sra h", "sra l", "sra (hl)", "sra a",

    "swap b", "swap c", "swap d", "swap e", "swap h", "swap l", "swap (hl)", "swap a",
    "srl b", "srl c", "srl d", "srl e", "srl h", "srl l", "srl (hl)", "srl a",

    "bit 0,b", "bit 0,c", "bit 0,d", "bit 0,e", "bit 0,h", "bit 0,l", "bit 0,(hl)", "bit 0,a",
    "bit 1,b", "bit 1,c", "bit 1,d", "bit 1,e", "bit 1,h", "bit 1,l", "bit 1,(hl)", "bit 1,a",
    "bit 2,b", "bit 2,c", "bit 2,d", "bit 2,e", "bit 2,h", "bit 2,l", "bit 2,(hl)", "bit 2,a",
    "bit 3,b", "bit 3,c", "bit 3,d", "bit 3,e", "bit 3,h", "bit 3,l", "bit 3,(hl)", "bit 3,a",
    "bit 4,b", "bit 4,c", "bit 4,d", "bit 4,e", "bit 4,h", "bit 4,l", "bit 4,(hl)", "bit 4,a",
    "bit 5,b", "bit 5,c", "bit 5,d", "bit 5,e", "bit 5,h", "bit 5,l", "bit 5,(hl)", "bit 5,a",
    "bit 6,b", "bit 6,c", "bit 6,d", "bit 6,e", "bit 6,h", "bit 6,l", "bit 6,(hl)", "bit 6,a",
    "bit 7,b", "bit 7,c", "bit 7,d", "bit 7,e", "bit 7,h", "bit 7,l", "bit 7,(hl)", "bit 7,a",

    "res 0,b", "res 0,c", "res 0,d", "res 0,e", "res 0,h", "res 0,l", "res 0,(hl)", "res 0,a",
    "res 1,b", "res 1,c", "res 1,d", "res 1,e", "res 1,h", "res 1,l", "res 1,(hl)", "res 1,a",
    "res 2,b", "res 2,c", "res 2,d", "res 2,e", "res 2,h", "res 2,l", "res 2,(hl)", "res 2,a",
    "res 3,b", "res 3,c", "res 3,d", "res 3,e", "res 3,h", "res 3,l", "res 3,(hl)", "res 3,a",
    "res 4,b", "res 4,c", "res 4,d", "res 4,e", "res 4,h", "res 4,l", "res 4,(hl)", "res 4,a",
    "res 5,b", "res 5,c", "res 5,d", "res 5,e", "res 5,h", "res 5,l", "res 5,(hl)", "res 5,a",
    "res 6,b", "res 6,c", "res 6,d", "res 6,e", "res 6,h", "res 6,l", "res 6,(hl)", "res 6,a",
    "res 7,b", "res 7,c", "res 7,d", "res 7,e", "res 7,h", "res 7,l", "res 7,(hl)", "res 7,a",

    "set 0,b", "set 0,c", "set 0,d", "set 0,e", "set 0,h", "set 0,l", "set 0,(hl)", "set 0,a",
    "set 1,b", "set 1,c", "set 1,d", "set 1,e", "set 1,h", "set 1,l", "set 1,(hl)", "set 1,a",
    "set 2,b", "set 2,c", "set 2,d", "set 2,e", "set 2,h", "set 2,l", "set 2,(hl)", "set 2,a",
    "set 3,b", "set 3,c", "set 3,d", "set 3,e", "set 3,h", "set 3,l", "set 3,(hl)", "set 3,a",
    "set 4,b", "set 4,c", "set 4,d", "set 4,e", "set 4,h", "set 4,l", "set 4,(hl)", "set 4,a",
    "set 5,b", "set 5,c", "set 5,d", "set 5,e", "set 5,h", "set 5,l", "set 5,(hl)", "set 5,a",
    "set 6,b", "set 6,c", "set 6,d", "set 6,e", "set 6,h", "set 6,l", "set 6,(hl)", "set 6,a",
    "set 7,b", "set 7,c", "set 7,d", "set 7,e", "set 7,h", "set 7,l", "set 7,(hl)", "set 7,a"
];

class Debugger
{
    private Cpu m_cpu;

    @property Cpu cpu() {
        return m_cpu;
    }

    @property Cpu cpu(Cpu cpu) {
        m_cpu = cpu;
        return m_cpu;
    }

    // TODO: return as string
    void dumpI() {
        ushort pc = m_cpu.registers.pc;
        ubyte opcode = m_cpu.memory.read8(pc);

        int argsz =  opcode_len[opcode] - 1;
        ubyte argv  = 0;
        for (ubyte i = 0; i < argsz; i++)
        {
            ushort addr = cast(ushort) ((m_cpu.registers.pc + 1 + i) << (8 * i));
            argv += m_cpu.memory.read8(addr);
        }

        writef("%04x: ", pc);
        if (opcode != 0xcb)
        {
            writef(opcode_fmt[opcode], argv);
        }
        else
        {
            writef("%s", cbext_asm[argv]);
        }
    }

    // TODO: return as string
    void dumpR()
    {
        Registers r = cpu.registers();
        writef("af=%04x bc=%04x de=%04x hl=%04x sp=%04x pc=%04x", r.af.v, r.bc.v, r.de.v, r.hl.v, r.sp, r.pc);
    }
}
