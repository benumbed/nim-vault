## 
## HCL (Hashicorp Configuration Language) parser
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import sequtils
import streams
import strformat
import strutils
import tables
import unicode

type HclParserError* = object of system.CatchableError
type HclSyntaxError* = object of HclParserError

type
    HclNodeKind* = enum
        HBool,
        HNumber,
        HString,
        HObject,
        HList,
        HComment

    HclNumberKind* = enum
        HNumDecimal,
        HNumHexadecimal,
        HNumOctal,
        HNumScientific,

    HclNumberObject* = object
        case kind*: HclNumberKind
        of HNumDecimal:
            dec*: int
        of HNumHexadecimal:
            hex*: int
        of HNumOctal:
            oct*: int
        of HNumScientific:
            sci*: string

    HclNode* = ref HclNodeObject
    HclNodeObject* {.acyclic.} = object
        case kind*: HclNodeKind
        of HBool:
            bval*: bool
        of HNumber:
            num*: HclNumberObject
        of HString:
            str*: string
        of HObject:
            fields*: OrderedTable[string, HclNode]
        of HList:
            elems*: seq[HclNode]
        of HComment:
            comment*: string


proc `$`*(this: HclNode): string

proc `$`*(this: HclNumberObject): string =
    case this.kind:
        of HNumDecimal:
            return $this.dec
        of HNumHexadecimal:
            return fmt"{this.hex:#x}"
        of HNumOctal:
            return fmt"{this.oct:#o}"
        of HNumScientific:
            return this.sci

proc processObject(this: OrderedTable[string, HclNode], indent=0): string =
    let stream = newStringStream()
    var tabs = ""
    var idx = indent

    while (idx > 0):
        tabs = fmt("{tabs}\t")
        idx.dec

    for key,value in this.pairs():
        if value.kind == HObject:
            stream.write(fmt("{tabs}{key} = {{\n"))
            let res = processObject(value.fields, indent+1)
            stream.write(fmt("{tabs}{res}"))
            stream.write(fmt("{tabs}}}\n"))
        else:
            stream.write(fmt("{tabs}{$key} = {$value}\n"))

    stream.setPosition(0)
    return stream.readAll()

proc `$`*(this: HclNode): string =
    ## repr for an HclNode
    case this.kind:
        of HBool:
            return $this.bval
        of HNumber:
            return $this.num
        of HString:
            return fmt("\"{this.str}\"")
        of HObject:
            return processObject(this.fields)
        of HList:
            let listStr = this.elems.join(", ")
            return fmt"[{listStr}]"
        of HComment:
            return fmt"# {this.comment}"

proc parseValue(elem: string): HclNode =
    ## Parses a value for an HclNode
    let strippedElem = unicode.strip(elem)

    # String
    if strippedElem.startsWith('"'):
        return HclNode(kind: HString, str: strippedElem.strip(chars = {'"'}))
    # Bool
    elif strippedElem == "true" or strippedElem == "false":
        return HclNode(kind: HBool, bval: strippedElem.parseBool)
    # Hex Number
    elif strippedElem.startsWith("0x"):
        return HclNode(kind: HNumber, num: HclNumberObject(kind: HNumHexadecimal, hex: fromHex[int](strippedElem)))
    # Octal Number
    elif strippedElem.startsWith("0"):
        return HclNode(kind: HNumber, num: HclNumberObject(kind: HNumOctal, oct: fromOct[int](strippedElem)))
    # Decimal Number
    elif strippedElem.allCharsInSet({'0','1','2','3','4','5','6','7','8','9'}):
        return HclNode(kind: HNumber, num: HclNumberObject(kind: HNumDecimal, dec: strippedElem.parseInt))
    # No idea, so keep it as a string
    else:
        return HclNode(kind: HString, str: strippedElem)


proc parseHcl2*(hs: Stream): HclNode =
    ## Parses a stream into HCL structures
    var curNode = HclNode(kind: HObject)
    var parentNodes: seq[HclNode] = @[]
    var curLine: int = 0;

    var objStack: seq[HclNode] = @[]
    var accumulator: seq[HclNode] = @[]
    var fieldStack: seq[string] = @[]
    var stringStack: seq[string] = @[]
    let commentMap: ref OrderedTable[int, (string, bool)] = newOrderedTable[int, (string, bool)]()

    # var depth 
    var inAssignment = false
    var inContainer = false
    var inObject = false

    const nonFieldStarters = {'{', '"', '[', '='}

    while not hs.atEnd:
        curLine.inc
        
        let line = unicode.strip(hs.readLine())
        if line.len == 0:
            continue

        # Entire line is comment
        if line.startsWith("#") or line.startsWith("//"):
            commentMap[curLine] = (line, false)
            continue

        let lineToks = unicode.split(unicode.strip(line))
        for tok in lineToks:
            var stripTok = unicode.strip(tok)

            echo stripTok

            if stripTok.startsWith('['):
                if fieldStack.len == 0:
                    raise newException(HclSyntaxError, fmt"Found list start without field assignment on line {curLine}")
                inContainer = true

                if stripTok.len == 1:
                    continue
                
                stripTok = stripTok[0..(stripTok.len-1)]

            if stripTok.endsWith(']'):
                inContainer = false
                # if stripTok.len > 1:

                let fieldName = fieldStack.pop()
                curNode.fields[fieldName] = HclNode(kind: HList, elems: accumulator)
                accumulator = @[]
        

            if stripTok.startsWith('"'):
                # We've found a string with spaces in it, so it was tokenized
                if not stripTok.endsWith('"'):
                    # accumulator.add(HclNode(kind: HString, str: stripTok[1..(stripTok.len-1)]))
                    stringStack.add(stripTok[1..(stripTok.len-1)])
                    continue

                if inContainer:
                    accumulator.add(HclNode(kind: HString, str: stripTok.strip(runes=[Rune('"')])))
                    continue

                # if inAssignment:
                #     objStack.add(HclNode(kind: HString, str: stripTok.strip(runes=[Rune('"')])))
                #     continue

                if fieldStack.len == 0:
                    raise newException(HclSyntaxError, fmt"Found nested object without parent object on line {curLine}")
                fieldStack.add(stripTok.strip(runes=[Rune('"')]))
                continue

            # Finish reconstructing a tokenized string
            if stripTok.endsWith('"'):
                if stringStack.len == 0:
                    raise newException(HclSyntaxError, fmt("Unexpected \" on line {curLine}"))
                
                # Add the final token
                if stripTok.len == 1:
                    stringStack.add(" ")
                else:
                    stringStack.add(stripTok[0..(stripTok.len-2)])
                stringStack = @[]
                    
                if inContainer:
                    accumulator.add(HclNode(kind: Hstring, str: stringStack.join(" ")))
                    continue

                curNode.fields[fieldStack.pop()] = HclNode(kind: Hstring, str: stringStack.join(" "))
                # inAssignment = false
                continue

            if stripTok.startsWith('{'):
                if fieldStack.len == 0:
                    raise newException(HclSyntaxError, fmt"Found object start without object name on line {curLine}")

                parentNodes.add(curNode)
                curNode = HclNode(kind: HObject)
                continue
            
            if stripTok.endsWith('}'):
                continue

            if stripTok.startsWith('='):
                # if inAssignment:
                #     raise newException(HclSyntaxError, fmt"Double assignment found on line {curLine} ({line})")
                inAssignment = true
                continue

            # if stripTok.startsWith('['):
            #     if fieldStack.len == 0:
            #         raise newException(HclSyntaxError, fmt"Found list start without field assignment on line {curLine}")
            #     inContainer = true

            #     if stripTok.len == 1:
            #         continue


            #     if inAssignment:
            #         let fieldName = fieldStack.pop()
            #         if curNode != nil:
            #             parentNodes.add(curNode)

            #         curNode = HclNode(kind: HList)

            # if stripTok.endsWith(']'):
            #     inContainer = false
            #     # if stripTok.len > 1:

            #     let fieldName = fieldStack.pop()
            #     curNode.fields[fieldName] = HclNode(kind: HList, elems: accumulator)
            #     accumulator = @[]
        

            # This line must always be the LAST in the checks
            if not (stripTok[0] in nonFieldStarters):
                if stringStack.len != 0:
                    stringStack.add(stripTok)
                    continue
                
                fieldStack.add(tok)
                continue
    
    echo curNode.fields.len

    return if parentNodes.len > 0: parentNodes[0] else: curNode


# proc parseHcl*(hs: Stream): HclNode =
#     ## Parses a stream into HCL structures
#     var curNode = HclNode(kind: HObject)
#     var parentNodes: seq[HclNode] = @[]
#     var curLine = 0;

#     while not hs.atEnd:
#         curLine.inc
#         var line = hs.readLine().strip()

#         # Entire line is comment
#         if line.startsWith("#") or line.startsWith("//") or line.len == 0:
#             continue

#         # A comment exists on the line somewhere and we need to strip it
#         # TODO: Need a way to save comments, I hate that they're stripped, so when this structure gets written back
#         # the comments are all gone
#         # Maybe what I could do is track comments in a separate data-structure?
#         let cmtLoc = line.find("#")
#         let cmtSlashLoc = line.find("//")
#         if cmtLoc != -1:
#             line = line[0..cmtLoc]
#         elif cmtSlashLoc != -1:
#             line = line[0..cmtSlashLoc]

#         # Assignments
#         let eqToks = line.split("=")
#         if eqToks.len > 1:
#             let fieldName = eqToks[0].strip()
#             let value = eqToks[1].strip()
#             if value.startsWith('['):
#                 # Single-line lists
#                 if value.endsWith(']'):
#                     let valArray = value.strip(chars = {'[', ']'}).split(",")
#                     curNode.fields[fieldName] = HclNode(kind: HList)
#                     for elem in valArray:
#                         curNode.fields[fieldName].elems.add(parseValue(elem))
#                     continue
#                 # TODO: Multi-line lists
#                 continue
#             else:
#                 curNode.fields[fieldName] = HclNode(kind: HString)
#                 curNode.fields[fieldName].str = eqToks[1].strip()
#             continue

#         let toks = line.split(" ")

#         # Object Terminators
#         if toks[0].strip().startsWith('}'):
#             discard parentNodes.pop()
#             curNode = parentNodes.pop()
#             continue


#         # Nested Objects
#         if toks.len > 2:
#             if toks[1].startsWith("\""):
#                 if not toks[2].startsWith('{'):
#                     raise newException(HclParserError, fmt"Missing opening brace on line {curLine}")
                
#                 let parentField = toks[0].strip()
#                 if not curNode.fields.hasKey(parentField):
#                     curNode.fields[parentField] = HclNode(kind: HObject)
#                 parentNodes.add(curNode)

#                 curNode = curNode.fields[parentField]

                
#                 let fieldName = toks[1].strip(chars = {'"'})
#                 if not curNode.fields.hasKey(parentField):
#                     curNode.fields[fieldName] = HclNode(kind: HObject)
#                 parentNodes.add(curNode)
#                 curNode = curNode.fields[fieldName]
        
#         # Non-nested Objects
#         elif toks.len == 2:
#             continue


#     echo curNode.fields["path"]
#     return curNode


proc parseHclFile*(filePath: string): HclNode =
    ## Parses a file which contains HCL
    let fs = newFileStream(filePath)
    return parseHcl2(fs)


when isMainModule:
    echo "HCL Parser"
    let hcl = parseHclFile("example.hcl")

    echo hcl

    # echo hcl.fields["path"].fields["sys/tools/hash/*"]