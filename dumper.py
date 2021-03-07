import re
import os

extension = {
    '.rpgmvp': '.png',
    '.rpgmvm': '.m4a',
    '.rpgmvo': '.ogg'
}


def get_code(path):
    with open(path, 'r', encoding='utf8') as file:
        data = file.read()
        result = re.findall(
            '''['"]encryptionKey['"]\s?:\s?['"]([0-9a-fA-F]{32})\s?['"]''', data)[0]
        return list(re.findall(r'(.{2})', result))


def dump_file(path, code):
    with open(path, 'rb') as file:
        data = bytearray(file.read())[16:]

        for i in range(16):
            data[i] = data[i] ^ int(code[i], 16)
        return data


def dump_img(path):
    header = bytearray.fromhex(
        '89 50 4E 47 0D 0A 1A 0A 00 00 00 0D 49 48 44 52'.replace(' ', ''))
    with open(path, 'rb') as file:
        data = bytearray(file.read())[32:]
    return header + data


def dump(path, code):
    if os.path.isfile(path):
        if path.endswith('.rpgmvp'):
            return dump_img(path)
        elif code is not None:
            return dump_file(path, code)


if __name__ == "__main__":
    codepath = 'System.json'
    filepath = 'Eve_13_0016.rpgmvp'
    ext = '.' + filepath.split('.')[-1]
    code = get_code(codepath)
    result = dump(filepath, code)
    if result is not None:
        with open(filepath.replace(ext, extension[ext]), 'wb') as file:
            file.write(result)
    # for root, dirs, files in os.walk('bgm'):
    #     for file in files:
    #         filepath = os.path.join(root, file)
    #         ext = '.' + filepath.split('.')[-1]
    #         code = get_code(codepath)
    #         result = dump(filepath, code)
    #         with open(filepath.replace(ext, extension[ext]), 'wb') as file:
    #             file.write(result)
