#include <iostream>
#include <stdlib.h>
#include <stdio.h>
#include <inttypes.h>
#include <map>
#include <vector>
#include <unistd.h> // for getopt()

using namespace std;

enum token_t {
    END=-1,
    WORD,
    DOT,
    COMMA,
    SEMI,
    COLON,
};

struct QPUreg {
    enum { A, B, ACCUM, SMALL } file;
    int num;
};

struct relocation {
    string label;
    int pc;
};

struct context {
    const char *stream;
    map<string, int> labels;
    int pc;
    vector<relocation> relocations;
};


static string addOps[] = {
    "nop", "fadd", "fsub", "fmin", "fmax", "fminabs", "fmaxabs",
    "ftoi", "itof", "XXX", "XXX", "XXX", "add", "sub", "shr",
    "asr", "ror", "shl", "min", "max", "and", "or", "xor", "not",
    "clz", "XXX", "XXX", "XXX", "XXX", "XXX", "v8adds", "v8subs" };

static string mulOps[] = {
    "nop", "fmul", "mul24", "v8muld", "v8min", "v8max", "v8adds",
    "v8subs" };

static uint8_t addOpCode(const string& word)
{
    for (int i=0; i < 32; i++) {
        if (word == addOps[i])
            return i;
    }

    return 0xFF;
}

static uint8_t mulOpCode(const string& word)
{
    for (int i=0; i < 8; i++) {
        if (word == mulOps[i])
            return i;
    }

    return 0xFF;
}


bool isRegisterWord(const string& word) { return word[0] == 'r'; }

string printRegister(const QPUreg& reg)
{
    char buffer[32];
    if (reg.file == QPUreg::A || reg.file == QPUreg::B) {
        snprintf(buffer, 32, "r%c%d", (reg.file == QPUreg::A) ? 'a' : 'b',
                                      reg.num);
    }
    else if (reg.file == QPUreg::ACCUM) {
        snprintf(buffer, 32, "r%d", reg.num);
    }
    else {
        snprintf(buffer, 32, ".0x%x.", reg.num);
    }

    return buffer;
}

bool parseRegister(const string& word, QPUreg& reg)
{
    if (word[0] != 'r')
        return false;

    int offset = 0;
    switch (word[1]) {
        case 'a': reg.file = QPUreg::A; offset = 2; break;
        case 'b': reg.file = QPUreg::B; offset = 2; break;
        default:
            reg.file = QPUreg::ACCUM;
            offset = 1;
    }
    // TODO: check that this is in range.  (ACCUM < 6, e.g.)
    reg.num = atoi(word.c_str() + offset);

    return true;
}

uint32_t parseImmediate(const string& str)
{
    // if there is an 'x' we assume it's hex.
    if (str.find_first_of("x") != string::npos)
        return strtoul(str.c_str(), NULL, 16);

    if (str.find_first_of(".f") != string::npos) {
        float f = strtof(str.c_str(), NULL);
        return *(uint32_t*)&f;
    }

    // otherwise decimal
    return strtoul(str.c_str(), NULL, 10);
}

uint8_t parseBranchCond(const string& str)
{
    if (str == "zf")            // all z flags set ("z full")
        return 0x0;
    if (str == "ze")            // all z flags clear ("z empty")
        return 0x1;
    if (str == "zs")            // any z flags set ("z set")
        return 0x2;
    if (str == "zc")            // any z flags clear ("z clear")
        return 0x3;
    if (str == "nf")            // all N flags set ("N full")
        return 0x4;
    if (str == "ne")            // all N flags clear ("N empty")
        return 0x5;
    if (str == "ns")            // any N flags set ("N set")
        return 0x6;
    if (str == "nc")            // any N flags clear ("N clear")
        return 0x7;
    if (str == "cf")            // all C flags set ("C full")
        return 0x8;
    if (str == "ce")            // all C flags clear ("C empty")
        return 0x9;
    if (str == "cs")            // any C flags set ("C set")
        return 0xa;
    if (str == "cc")            // any C flags clear ("C clear")
        return 0xb;
    if (str == "*")             // always
        return 0xf;

    // throw some exceptions
    cerr << "Invalid branch condition: " << str << endl;
    exit(0);
}

uint8_t setALUMux(const QPUreg& reg)
{
    switch (reg.file) {
        case QPUreg::A: return 0x6;
        case QPUreg::B: return 0x7;
        case QPUreg::ACCUM:
            if (reg.num > 6 || reg.num < 0) {
                cerr << "Invalid accumulator register; out of range" << endl;
                exit(0);
            }
            return reg.num;
        case QPUreg::SMALL: return 0x7;
    }
}


token_t nextToken(const char *stream, string& out, const char **ptr)
{
    char buffer[128];
    int i = 0;

    *ptr = stream;
    if (!stream || !*stream)
        return END;

    while (*stream == ' ' || *stream == '\t')
        stream++;

    if (*stream == '\0')
        return END;

    if (isdigit(*stream))
    {
        // read until we don't find a hex digit, x (for hex) or .
        while (isxdigit(*stream) || isdigit(*stream) || *stream == '.' || *stream == 'x') {
            buffer[i++] = *stream++;
            if (*stream == 0 || i > sizeof(buffer) - 1)
                break;
        }
        buffer[i++] = '\0';
        out = buffer;
        *ptr = stream;

        return WORD;
    }

    if (*stream == '.') { *ptr = stream+1; return DOT; }
    if (*stream == ',') { *ptr = stream+1; return COMMA; }
    if (*stream == ';') { *ptr = stream+1; return SEMI; }
    if (*stream == '#') { *ptr = stream+1; return END; }
    if (*stream == ':') { *ptr = stream+1; return COLON; }

    while (*stream != '.' && *stream != ',' && *stream != ';'
                          && *stream != ' ' && *stream != '\t'
                          && *stream != ':')
    {
        buffer[i++] = *stream++;
        if (*stream == 0 || i > sizeof(buffer)-1)
            break;
    }

    buffer[i++] = '\0';
    out = buffer;
    *ptr = stream;

    return WORD;
}


bool aluHelper(const char *stream, QPUreg& dest, QPUreg& r1, QPUreg& r2, uint8_t& sig, const char **ptr)
{
    string token_str;
    token_t tok = nextToken(stream, token_str, &stream);

    if (tok == DOT) {
        // conditional
        nextToken(stream, token_str, &stream);
        cout << "flag/conditional = " << token_str << endl;
        if (token_str == "tmu")
            sig = 10;
        else if (token_str == "tend")
            sig = 3;
        tok = nextToken(stream, token_str, &stream);
    }

    // this is supposed to be the destination register
    if (tok != WORD) {
        cout << "Expecting word.  Got: " << token_str << endl;
        return false;
    }

    parseRegister(token_str, dest);
    tok = nextToken(stream, token_str, &stream);
    if (tok != COMMA) return false;
    tok = nextToken(stream, token_str, &stream);
    parseRegister(token_str, r1);

    tok = nextToken(stream, token_str, &stream);
    if (tok != COMMA) return false;
    tok = nextToken(stream, token_str, &stream);
    if (!parseRegister(token_str, r2)) {
        r2.file = QPUreg::SMALL;
        uint32_t imm = parseImmediate(token_str);
        // double check handle negative values
        if (imm < 16)
            r2.num = imm;
        else {
            cerr << "TODO: Unhandled small immediate" << endl;
            return false;
        }
    }

    /*
    cout << "dest: " << printRegister(dest) << ", r1: "
                     << printRegister(r1) << ", r2: "
                     << printRegister(r2) << endl;
                     */

    *ptr = stream;
    return true;
}


uint64_t assembleALU(context& ctx, string word)
{
    string token_str;
    uint8_t add_op = addOpCode(word);
    if (add_op == 0xFF) {
        cout << "FATAL (assert).  Bad opcode" << endl;
        return -1;
    }

    QPUreg addDest, addR1, addR2;
    QPUreg mulDest, mulR1, mulR2;

    uint8_t sig = 0x1;          // no-signal (TODO: plumb signals through)
    if (!aluHelper(ctx.stream, addDest, addR1, addR2, sig, &ctx.stream))
        return -1;

    token_t tok = nextToken(ctx.stream, token_str, &ctx.stream);
    // this should be a semi-colon
    tok = nextToken(ctx.stream, token_str, &ctx.stream);
    uint8_t mul_op = mulOpCode(token_str);
    if (mul_op == 0xFF) {
        cout << "FATAL (assert).  Bad opcode" << endl;
        return -1;
    }

    bool skipParseMul(false);
    if (mul_op == 0) {
        // nop.  If the next token is a semi or END, we'll generate
        // the registers for them
        const char *discard;
        tok = nextToken(ctx.stream, token_str, &discard);
        if (tok == END || tok == SEMI) {
            mulDest.num = 39;
            mulDest.file = (addDest.file == QPUreg::A) ? QPUreg::B : QPUreg::A;
            mulR1 = addR1;
            mulR2 = addR2;
            skipParseMul = true;
        }
    }

    if (!skipParseMul) {
        uint8_t junk;
        if (!aluHelper(ctx.stream, mulDest, mulR1, mulR2, junk, &ctx.stream))
            return -1;
    }

    uint64_t ins = 0x0;
    uint8_t cond_add = 0x1;
    uint8_t cond_mul = 0x1;
    uint8_t sf = 0x1;
    if (add_op == 0)
        sf = 0x0;           // no set flags on nop

    // TODO: constraints.  We can only read from file A and file B once (dual-port)

    uint8_t ws = 0x0;
    // If the add pipe specifies file b for output, ws = 1
    if (addDest.file == QPUreg::B)
        ws = 0x1;
    // if ws == 1, mul pipe must specify file a for output
    if (ws == 0x1 && mulDest.file != QPUreg::A) {
        cout << "constraint check failed.  mul pipe must specify register file A when write-swap set" << endl;
        return -1;
    }
    // if ws == 0, mul pipe must specify file b for output
    if (ws == 0x0 && mulDest.file != QPUreg::B) {
        cout << "constraint check failed.  mul pipe must specify register file B when write-swap clear" << endl;
        return -1;
    }

    // TODO: handle the accumulators and the small immediate
    uint8_t read_a = 0x0;
    if (addR1.file == QPUreg::A) read_a = addR1.num;
    else if (addR2.file == QPUreg::A) read_a = addR2.num;
    else if (mulR1.file == QPUreg::A) read_a = mulR1.num;
    else if (mulR2.file == QPUreg::A) read_a = mulR2.num;

    uint8_t read_b = 0x0;
    if (addR1.file == QPUreg::B) read_b = addR1.num;
    else if (addR2.file == QPUreg::B) read_b = addR2.num;
    else if (mulR1.file == QPUreg::B) read_b = mulR1.num;
    else if (mulR2.file == QPUreg::B) read_b = mulR2.num;

    // checks:
    //   read_a not set and one of the muxes specifies file A ...
    //   same for read_b
    //   read_b set and there is a small immediate value

    // we could have immediates in the first register slot but not sure it makes sense
    // As above, we should check that read_b is not already set
    if (addR2.file == QPUreg::SMALL)    { read_b = addR2.num; sig = 13; }
    if (mulR2.file == QPUreg::SMALL)    { read_b = mulR2.num; sig = 13; }

    uint8_t add_a = setALUMux(addR1) & 0x7;
    uint8_t add_b = setALUMux(addR2) & 0x7;
    uint8_t mul_a = setALUMux(mulR1) & 0x7;
    uint8_t mul_b = setALUMux(mulR2) & 0x7;
    read_a &= 0x3f;
    read_b &= 0x3f;
    mul_op &= 0x7;
    add_op &= 0x1f;
    addDest.num &= 0x3f;
    mulDest.num &= 0x3f;
    cond_add &= 0x7;
    cond_mul &= 0x7;
    sf &= 0x1;
    ws &= 0x1;

    printf("Assembling ALU instruction: %s, %d, %d\n", printRegister(addDest).c_str(), ws, sig);

    ins = ((uint64_t)sig << 60) | ((uint64_t)cond_add << 49) | ((uint64_t)cond_mul << 46) | ((uint64_t)sf << 45) | ((uint64_t)ws << 44);
    ins |= ((uint64_t)addDest.num << 38) | ((uint64_t)mulDest.num << 32) | ((uint64_t)mul_op << 29) | ((uint64_t)add_op << 24);
    ins |= ((uint64_t)read_a << 18) | ((uint64_t)read_b << 12) | ((uint64_t)add_a << 9) | ((uint64_t)add_b << 6) | ((uint64_t)mul_a << 3) | mul_b;

    return ins;
}

uint64_t assembleLDI(context& ctx, string word)
{
    cout << "Assembling LDI instruction ... " << endl;

    string token_str;
    token_t tok = nextToken(ctx.stream, token_str, &ctx.stream);

    if (tok == DOT) {
        // conditional ... conditionals should be on each register ?
        cout << "conditional ... ";
        // chew the conditional
        nextToken(ctx.stream, token_str, &ctx.stream);

        tok = nextToken(ctx.stream, token_str, &ctx.stream);
    }

    // this is supposed to be the register
    if (tok != WORD) return -1;

    QPUreg register1, register2;
    // check errors here
    parseRegister(token_str, register1);
    tok = nextToken(ctx.stream, token_str, &ctx.stream);
    if (tok != COMMA) return -1;
    tok = nextToken(ctx.stream, token_str, &ctx.stream);

    // this can either be another register
    // (in which case we'll use both ALUs to set)
    // or an immediate value (in which case we'll use rX39)
    register2.num = 39;
    register2.file = (register1.file == QPUreg::A) ? QPUreg::B : QPUreg::A;
    if (isRegisterWord(token_str)) {
        parseRegister(token_str, register2);
        tok = nextToken(ctx.stream, token_str, &ctx.stream);
        // check that this is a comma ...
    }

    tok = nextToken(ctx.stream, token_str, &ctx.stream);
    unsigned int immediate = parseImmediate(token_str);

    cout << "r1: " << printRegister(register1) << ", r2: "
                   << printRegister(register2) << ", immed: 0x"
                   << hex << immediate << dec << endl;

    while (nextToken(ctx.stream, token_str, &ctx.stream) != END)
        ;

    uint32_t high = (uint32_t)0xE00 << 20;
    high |= (uint32_t)0x1 << 17;      // cond_add
    high |= (uint32_t)0x1 << 14;      // cond_mul
    high |= (uint32_t)0x0 << 13;      // sf
    high |= (uint32_t)0x0 << 12;      // ws
    uint8_t addreg = (register1.file == QPUreg::A) ? register1.num : register2.num;
    uint8_t mulreg = (register1.file == QPUreg::B) ? register1.num : register2.num;
    high |= (uint32_t)addreg << 6;
    high |= mulreg;
    uint64_t ins = ((uint64_t)high << 32) | immediate;

    return ins;
}

uint64_t assembleBRANCH(context& ctx, string word)
{
    cout << "Assembing BRANCH instruction" << endl;

    QPUreg dest;
    string token_str;
    token_t tok = nextToken(ctx.stream, token_str, &ctx.stream);

    // relative or absolute branch?
    uint8_t relative = 1;
    if (word == "bra")
        relative = 0;

    uint8_t branchCondition = 0xf;          // by default: always (unconditional branch)
    if (tok == DOT) {
        // conditional
        nextToken(ctx.stream, token_str, &ctx.stream);
        branchCondition = parseBranchCond(token_str);
        tok = nextToken(ctx.stream, token_str, &ctx.stream);
    }

    // this is the destination register
    if (tok != WORD) {
        cerr << "branch expecting destination register." << endl;
        return -1;
    }
    parseRegister(token_str, dest);
    tok = nextToken(ctx.stream, token_str, &ctx.stream);
    if (tok != COMMA) return false;
    tok = nextToken(ctx.stream, token_str, &ctx.stream);
    if (tok != WORD) {
        cerr << "branch expecting label/target" << endl;
        return -1;
    }

    // look it up in the labels map
    int target = 0xFFFFFFFF;
    if (ctx.labels.count(token_str) < 1) {
        relocation r;
        r.label = token_str;
        r.pc = ctx.pc;
        ctx.relocations.push_back(r);
    } else
        target = ctx.labels[token_str];
    int offset = target - (ctx.pc+4*8);

    uint8_t raddr_a = 0;           // raddr_a is only 5-bits?
    uint8_t use_reg = 0;
    // if there's a third argument, it is a register offset
    const char *discard;
    tok = nextToken(ctx.stream, token_str, &discard);
    if (tok == COMMA) {
        QPUreg offsetReg;
        // chew the comma we just read
        ctx.stream = discard;
        tok = nextToken(ctx.stream, token_str, &ctx.stream);
        parseRegister(token_str, offsetReg);
        if (offsetReg.file != QPUreg::A) {
            cerr << "branch target offset register must be file A" << endl;
            return -1;
        }
        if (offsetReg.num > 31) {
            cerr << "branch target offset register must be < 32" << endl;
            return -1;
        }
        raddr_a = offsetReg.num;
        use_reg = 1;
    }

    uint8_t waddr_add = 39;         // link address appears at ALU outputs
    uint8_t waddr_mul = 39;
    if (dest.file == QPUreg::A) waddr_add = dest.num;
    if (dest.file == QPUreg::B) waddr_mul = dest.num;

    uint64_t ins = (uint64_t)0xF << 60;
    ins |= (uint64_t)branchCondition << 52;
    ins |= (uint64_t)relative << 51;
    ins |= (uint64_t)use_reg << 50;
    ins |= (uint64_t)raddr_a << 45;
    ins |= (uint64_t)0x0 << 44;                       // write-swap
    ins |= (uint64_t)waddr_add << 38;
    ins |= (uint64_t)waddr_mul << 32;
    ins |= (uint32_t)offset;

    return ins;
}

uint64_t assembleSEMA(context& ctx, string word)
{

    uint64_t ins = (uint64_t)0x74 << 57;

    string token_str;
    token_t tok = nextToken(ctx.stream, token_str, &ctx.stream);
    if (tok != WORD) {
        cerr << "semaphore instruction expecting down/up or acquire/release" << endl;
        return -1;
    }

    uint8_t sa = 0;             // up
    if (token_str == "down" || token_str == "acquire")
        sa = 1;

    tok = nextToken(ctx.stream, token_str, &ctx.stream);
    if (tok != COMMA)   return -1;
    tok = nextToken(ctx.stream, token_str, &ctx.stream);
    uint32_t imm = parseImmediate(token_str);
    if (imm > 15) {
        cerr << "semaphore out of range" << endl;
        return -1;
    }
    // cond_add, cond_mul = NEVER, ws, sf = false
    ins |= (uint64_t)39 << 38;          // waddr_add
    ins |= (uint64_t)39 << 32;          // waddr_mul
    ins |= sa << 4;
    ins |= (uint8_t)imm;

    cout << "Assembling SEMAPHORE instruction (" << imm << "), " << (int)sa << endl;

    return ins;
}


int main(int argc, char **argv)
{
    char *outfname = 0;
    int c;

    while ((c = getopt(argc, argv, "o:")) != -1) {
        switch (c) {
            case 'o':
                outfname = optarg;
                break;
        }
    }

    if (!outfname) {
        cerr << "Usage: " << argv[0] << " -o <output>" << endl;
        return -1;
    }

    FILE *outfile = fopen(outfname, "w");
    if (!outfile)
    {
        cerr << "Unable to open output file output.bin" << endl;
        return -1;
    }

    char line[128];
    string token_string;

    struct context ctx;
    ctx.pc = 0;

    vector<uint64_t> instructions;

    int lineNo = 0;
    while (cin.getline(line, 128))
    {
        lineNo++;
        const char *p = line;
        ctx.stream = p;
        token_t tok = nextToken(ctx.stream, token_string, &ctx.stream);

        if (tok == END)
            continue;

        if (tok == WORD)
        {
            // read-ahead to see if the next token is a colon in which case
            // this is a label.
            const char *discard = NULL;
            string nextTokenStr;
            if (nextToken(ctx.stream, nextTokenStr, &discard) == COLON) {
                ctx.labels[token_string] = ctx.pc;
                continue;
            }

            enum { INVALID, ALU, BRANCH, LDI, SEMA } opType = INVALID;
            if (addOpCode(token_string) != 0xFF || mulOpCode(token_string) != 0xFF)
                opType = ALU;
            if (token_string == "ldi") opType = LDI;
            if (token_string == "bra" || token_string == "brr") opType = BRANCH;
            if (token_string == "sema") opType = SEMA;

            if (opType == INVALID) {
                cerr << "Unable to assemble line " << lineNo << " : " << line << endl;
                cerr << " ... invalid opcode" << endl;
                return -1;
            }

            uint64_t ins = 0;
            switch (opType) {
                case ALU: ins = assembleALU(ctx, token_string); break;
                case BRANCH: ins = assembleBRANCH(ctx, token_string); break;
                case LDI: ins = assembleLDI(ctx, token_string); break;
                case SEMA: ins = assembleSEMA(ctx, token_string); break;
            }

            if (ins == (uint64_t)-1) {
                cerr << "Error on line " << lineNo << " : " << line << endl;
                return -1;
            }

            instructions.push_back(ins);
            ctx.pc += 8;            // bytes;
        }
    }

    // Process relocations
    ctx.labels["ZERO"] = 0x0;
    for (int i=0; i < ctx.relocations.size(); i++)
    {
        relocation& r = ctx.relocations[i];
        if (ctx.labels.count(r.label) < 1)
        {
            cerr << "undefined label: " << r.label << endl;
            return -1;
        }
        int offset = ctx.labels[r.label] - (r.pc + 4*8);
        if (r.label == "ZERO")
            offset = 0x0;
        cout << "Processing relocation at " << r.pc << " : " << r.label
                                            << " : " << offset << endl;
        uint64_t ins = instructions[r.pc / 8];
        ins &= (uint64_t)0xFFFFFFFF << 32;   // zero bottom 32-bits for new value
        ins |= (uint32_t)offset;
        instructions[r.pc / 8] = ins;
    }

    for (int i=0; i < instructions.size(); i++)
        fwrite(&instructions[i], sizeof(uint64_t), 1, outfile);

    fclose(outfile);
    cout << "Done.  Num instructions: " << instructions.size() << ", "
         << instructions.size() * 8 << " bytes." << endl;
}
