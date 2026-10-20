import binascii
import shutil
import tempfile
import os

def calculate_crc32(filename):
    crc = 0
    with open(filename, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            crc = binascii.crc32(chunk, crc)
    return f"{crc & 0xFFFFFFFF:08X}"

filename = 'target/bin/kernel.bin'

# Create a temporary copy of the original file.
fd, temp_filename = tempfile.mkstemp()
os.close(fd)

try:
    shutil.copy2(filename, temp_filename)

    # Modify the copy: zero 4 bytes at decimal offset 10.
    with open(temp_filename, 'r+b') as f:
        f.seek(10)
        f.write(b'\x00' * 4)

    # Calculate CRC32 using the modified copy.
    print("CRC32 Checksum:", calculate_crc32(temp_filename))

finally:
    # Delete the temporary copy, even if an error occurs.
    if os.path.exists(temp_filename):
        os.remove(temp_filename)
