import tables, regex, strutils, sequtils, streams, os


const fileExtensions = {
  ".rpgmvp": ".png",
  ".png_": ".png",
  ".rpgmvm": ".m4a",
  ".m4a_": ".m4a",
  ".rpgmvo": ".ogg",
  ".ogg_": ".ogg"
}.toTable
proc createPngHeader(): array[16, uint8] =
  for i in 0..15:
    result[i] = "89 50 4E 47 0D 0A 1A 0A 00 00 00 0D 49 48 44 52".splitWhitespace[i].parseHexInt.uint8
const pngHeader: array[16, uint8] = createPngHeader()


proc getCode(path: string): seq[uint8] =
  if fileExtensions.hasKey(path.splitFile.ext) and fileExtensions[path.splitFile.ext] == ".png":
    let fs = path.newFileStream(fmRead)
    defer: fs.close
    fs.setPosition(16)
    for i in 0..15:
      result.add(fs.readUint8 xor pngHeader[i])
  else:
    try:
      let data = path.readFile
      let code = data[data.findAll("""['"]encryptionKey['"]\s?:\s?['"]([0-9a-fA-F]{32})\s?['"]""".re)[0].group(0)[0]]
      result = code.findAll(".{2}".re).mapIt(code[it.boundaries].parseHexInt.uint8)
    except:
      raise newException(Exception, "Unable to find code.")

proc dumpFile(path: string, code: seq[uint8]): bool =
  let ext = path.splitFile.ext
  if not fileExtensions.hasKey(ext): return false
  let destPath = path.replace(ext, fileExtensions[ext])

  let srcFs = path.newFileStream(fmRead)
  let destFs = destPath.newFileStream(fmWrite)
  defer:
    srcFs.close
    destFs.close
  if srcFs.isNil: echo "Can't open source path."
  if destFs.isNil: echo "Can't open destination path."
  if srcFs.isNil or destFs.isNil: return false

  if fileExtensions[ext] == ".png":
    srcFs.setPosition(32)
    destFs.write(pngHeader)
  else:
    srcFs.setPosition(16)
    for i in 0..15:
      destFs.write(srcFs.readUint8 xor code[i])
  destFs.write(srcFs.readAll)

  return true

when defined(release): {.passL: "-s"}

when isMainModule:
  import strformat
  let params = commandLineParams()
  if params.len == 0: quit()

  var files = newSeq[string]()
  var code = newSeq[uint8]()
  for path in params:
    if path.dirExists:
      for file in path.walkDirRec:
        if fileExtensions.hasKey(file.splitFile.ext): files.add(file.absolutePath)
        elif file.splitFile.name & file.splitFile.ext == "System.json": code = file.absolutePath.getCode
        if code.len == 0 and fileExtensions.hasKey(file.splitFile.ext) and fileExtensions[file.splitFile.ext] == ".png": code = file.absolutePath.getCode
    elif path.fileExists:
      if fileExtensions.hasKey(path.splitFile.ext): files.add(path.absolutePath)
      elif path.splitFile.name & path.splitFile.ext == "System.json": code = path.absolutePath.getCode
      if code.len == 0 and fileExtensions.hasKey(path.splitFile.ext) and fileExtensions[path.splitFile.ext] == ".png": code = path.absolutePath.getCode
  if files.len == 0: quit()
  for f in files: echo f

  if code.len > 0:
    echo &"Code is found: {code.mapIt(it.toHex(2)).join}. Continue? [Y/n]"
    let answer = readLine(stdin).toLowerAscii
    if answer != "y" and answer.len > 0: quit()
  elif files.anyIt(fileExtensions[it.splitFile.ext] == ".png"):
    echo "Code not found, you can only dump images without knowing the code. Continue? [y/N]"
    if readLine(stdin).toLowerAscii != "y": quit()
  else:
    echo "Code not found."
    quit()
  for file in files:
    stdout.write &"Dumping {file} ... "
    if dumpFile(file, code): echo "Success." else: echo "Failed."

  echo "Remove original files? [y/N]"
  if readLine(stdin).toLowerAscii != "y": quit()
  for file in files: file.removeFile
