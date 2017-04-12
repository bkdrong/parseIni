#
#
#            ParseIni
#        (c) Copyright 2015 bkdrong
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## scan.nim 实现词法分析
## 
import
    windows,tables,os
proc printf(formatstr: cstring) {.importc: "printf", varargs,
header: "<stdio.h>".}
type 
    TOKEN_KIND = enum
        TK_NONE,    #如果是TK_NONE,则出错了
        TK_ID,      #标识符
        TK_EQU,     #等号
        TK_STR,     #字符串
        TK_INT,     #整数类型
        TK_SECTION  #区域

    SCAN_STATE = enum
        SS_START,
        SS_INID,
        SS_INSTR,
        SS_ININT,
        SS_INSECTION,
        SS_END
    TTOKEN = object
        kind:TOKEN_KIND
        value:string
    TSymbolList = Table[string,string]
    TSection = Table[string,TSymbolList]

const 
    END_CHAR = '\0'        
#全局变量区
var 
    g_buffer : string  = """
    [bkdrong]
        name  = "ronggf"
        scope = 90
        age   = 41
        num   = 20
        nation = "china"
    [xieglt]
        name  = "xielt"
        scope = 80
        age   = 37
        num   = 16
        nation = "japen"    
    """
    g_buffer_pos : int = 0
    g_curr_token : TTOKEN
    g_section_lst:TSection = initTable[string,TSymbolList]()
#获得下一个字符
proc getCharFormBuffer():char = 
    if g_buffer_pos < g_buffer.len :        
        result = g_buffer[g_buffer_pos]
    else: 
        result = '\0'
    g_buffer_pos+=1

proc backBuffer() =
    g_buffer_pos-=1   
#get a token from g_buffer
proc getTok():TTOKEN = 
    var 
        state = SS_START
        token_value :string =""
        ret_val:TTOKEN
    while true:        
        var c = getCharFormBuffer()
        #printf("get char 0x%x\n",c)
        case state :
        of SS_START:
            if c in {'a'..'z','A'..'Z'} :
                state = SS_INID
                token_value =token_value & c
            elif c =='"':
                state = SS_INSTR                
            elif c=='=':
                state = SS_END
                ret_val.kind = TK_EQU
                ret_val.value="="
            elif c in {'0'..'9'}:
                state = SS_ININT
                token_value = token_value & c
            elif c == '[':
                state = SS_INSECTION
            elif c == END_CHAR:
                state = SS_END
                ret_val.kind = TK_NONE
        of SS_INID:
            if c notin {'a'..'z','A'..'Z','0'..'9','_'}:
                backBuffer()
                ret_val.kind =TK_ID
                ret_val.value = token_value
                state = SS_END
            else:
                token_value = token_value & c
        of SS_ININT:
            if c notin {'0'..'9'} :
                backBuffer()
                ret_val.kind =TK_INT
                ret_val.value = token_value
                state = SS_END
            else:
                token_value = token_value & c
        of SS_INSTR:
            if c!='"':
                token_value = token_value &c
            else :
                ret_val.kind = TK_STR
                ret_val.value = token_value
                state = SS_END
        of SS_INSECTION:
            if c!=']':
                token_value = token_value &c
            else :
                ret_val.kind = TK_SECTION
                ret_val.value = token_value
                state = SS_END
        else:discard
        if state == SS_END:
            return ret_val
proc match(kind:TOKEN_KIND) =
    if g_curr_token.kind == kind :
        g_curr_token = getTok()
    else :
        echo "expected :",kind," but got ",g_curr_token.kind
        quit(1)
proc test_gettoken() =
    while true:
        var tok :TTOKEN
        tok = getTok()
        if tok.kind == TK_NONE:
            break
        else :
            echo tok
proc assignStmt(symlst:var TSymbolList):bool =
        if g_curr_token.kind == TK_ID :
            var 
                sym_name:string
                sym_value:string
            sym_name = g_curr_token.value
            match(TK_ID)
            match(TK_EQU)            

            if g_curr_token.kind == TK_STR:
                sym_value = g_curr_token.value
                match(TK_STR)                
            elif g_curr_token.kind == TK_INT:
                sym_value = g_curr_token.value
                match(TK_INT)
            else:
                sym_value ="no value"
            symlst.add(sym_name,sym_value)
            result = true
        elif g_curr_token.kind == TK_NONE or g_curr_token.kind == TK_SECTION:
            result = false
        else:
            echo "assignListStmt failed"
            quit(1)

proc assignListStmt(symlst: var TSymbolList) =
    while true :
        if not assignStmt(symlst) :
            break
proc stmt() =      
    g_curr_token = getTok()
    while true:
        if g_curr_token.kind == TK_SECTION:
            var section_name = g_curr_token.value
            match(TK_SECTION)
            var sym_list : TSymbolList = initTable[string,string]()
            assignListStmt(sym_list)
            #echo "section_name ",section_name
            g_section_lst.add(section_name,sym_list)
            #echo "item:",g_section_lst[section_name]
            #echo "sym_list",sym_list
        elif g_curr_token.kind==TK_NONE :
            break
        else:
            echo "tk is = ",g_curr_token
            quit(1)
proc readINI(filename:string,section_name:string,key_name:string):string =
    result=""
    var 
        file = open(filename)
        content : string = ""
    if file!=nil :
        for str in lines(file) :
            content &= str & "\n"
        g_buffer = content
        stmt()
        try:
            let symlst = g_section_lst[section_name]
            result = symlst[key_name]
        except:
            echo "except:",repr(getCurrentExceptionMsg())
            #echo "can not find the key_name:",key_name," in section_name:",section_name
    else:
        echo "open file:",filename," failed"
proc main() =
    echo "CPU:",hostCPU," OS:",hostOS
    if paramCount() < 1:
        echo ";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;"
        echo "scan inifile"
        echo "example:scan\x0a\x09 c:\\test\\haha.ini"
        echo ";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;"
        return

    let filename = commandLineParams()[0]
    if not existsFile(filename):
        return
    stdout.write("input a section string:")
    let section_name = readline(stdin)
    stdout.write("input a key string:")
    let key_name = readline(stdin)
    echo "result = " , readINI(filename,section_name,key_name)
main()
#test_gettoken()            
#stmt()
#echo repr(g_symbol_lst)
#echo g_section_lst




