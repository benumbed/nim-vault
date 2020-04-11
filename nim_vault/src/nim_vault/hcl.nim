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

type HclParserError* = object of system.CatchableError


type
    HclNodeKind* = enum
        HBool,
        HNumber,
        HString,
        HObject,
        HList

    HclNumberKind* = enum
        HNumDecimal,
        HNumHexadecimal,
        HNumOctal,
        HNumScientific,

    HclNumberObject* = object

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


proc `$`*(this: HclNode): string

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
    # var resBlocks: seq[string] = @[]

    case this.kind:
        of HBool:
            return $this.bval
        of HNumber:
            return "number"
        of HString:
            return this.str
        of HObject:
            return processObject(this.fields)
        of HList:
            return "list"


proc parseHcl*(hs: Stream): HclNode =
    ## Parses a stream into HCL structures
    var curNode = HclNode(kind: HObject)
    var parentNodes: seq[HclNode] = @[]
    var curLine = 0;

    while not hs.atEnd:
        curLine.inc
        var line = hs.readLine().strip()
        if line.startsWith("#") or line.startsWith("//") or line.len == 0:
            continue

        let cmtLoc = line.find("#")
        let cmtSlashLoc = line.find("//")
        if cmtLoc != -1:
            line = line[0..cmtLoc]
        elif cmtSlashLoc != -1:
            line = line[0..cmtSlashLoc]

        let eqToks = line.split("=")
        if eqToks.len > 1:
            let fieldName = eqToks[0].strip()
            curNode.fields[fieldName] = HclNode(kind: HString)
            curNode.fields[fieldName].str = eqToks[1].strip()
            continue
        
        let toks = line.split(" ")
        if toks[0].strip().startsWith('}'):
            discard parentNodes.pop()
            curNode = parentNodes.pop()
            continue
        
        if toks.len > 2:
            # Nested Object
            if toks[1].startsWith("\""):
                if not toks[2].startsWith('{'):
                    raise newException(HclParserError, fmt"Missing opening brace on line {curLine}")
                
                let parentField = toks[0].strip()
                if not curNode.fields.hasKey(parentField):
                    curNode.fields[parentField] = HclNode(kind: HObject)
                parentNodes.add(curNode)

                curNode = curNode.fields[parentField]

                
                let fieldName = toks[1].strip(chars = {'"'})
                if not curNode.fields.hasKey(parentField):
                    curNode.fields[fieldName] = HclNode(kind: HObject)
                parentNodes.add(curNode)
                curNode = curNode.fields[fieldName]

    echo curNode.fields["path"]
    return curNode


proc parseHclFile*(filePath: string): HclNode =
    ## Parses a file which contains HCL
    let fs = newFileStream(filePath)
    return parseHcl(fs)


when isMainModule:
    echo "HCL Parser"
    let hcl = parseHclFile("example.hcl")

    # echo hcl

    # echo hcl.fields["path"].fields["sys/tools/hash/*"]