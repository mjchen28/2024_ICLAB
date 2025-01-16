import random

SEED = "JAYS ICLAB"
random.seed(SEED)

datfile = open('dram.dat', 'w')
debugfile = open('debug.txt', 'w')

for i in range(256):
    base = i*8 + 0x10000
    # Check that A and B are 12-bit values
    A = random.randint(0, 0xfff)
    B = random.randint(0, 0xfff)
    C = random.randint(0, 0xfff)
    D = random.randint(0, 0xfff)
    Month = random.randint(1, 12)
    Day = 0
    if(Month == 2):
      Day = random.randint(1, 28)
    elif Month in [4, 6, 9, 11]:
      Day = random.randint(1, 30)
    else:
      Day = random.randint(1, 31)
    # Extract parts of A and B
    B_lower_8 = B     
    A_lower_4 = A      
    B_upper_4 = (B >> 8) 
    A_upper_8 = A >> 4    

    D_lower_8 = D    
    C_lower_4 = C        
    D_upper_4 = (D >> 8)
    C_upper_8 = C >> 4

    result = (D_lower_8 << 16) | (C_lower_4 << 12) | (D_upper_4 << 8) | C_upper_8

    # Format the result as a 32-bit hex number
    result_hex = f"{result:06X}"

    result_with_space = f"{Day:02X}" + " " + result_hex[:2] + " " + result_hex[2:4] + " " + result_hex[4:6]
    print(f"@{base:05X}", file=datfile)
    # print(f"{Day:02X}")
    # print(f"{C:03X}")
    # print(f"{D:03X}")
    print(result_with_space, file=datfile)
    
    # Concatenate according to the specified order:
    # A[7:0] | B[3:0] | A[11:8] | B[11:4]
    result = (B_lower_8 << 16) | (A_lower_4 << 12) | (B_upper_4 << 8) | A_upper_8

    # Format the result as a 32-bit hex number
    result_hex = f"{result:06X}"

    result_with_space = f"{Month:02X}" + " " + result_hex[:2] + " " + result_hex[2:4] + " " + result_hex[4:6]
    print(f"@{base+4:05X}", file=datfile)
    # print(f"{Month:02X}")
    # print(f"{A:03X}")
    # print(f"{B:03X}")
    print(result_with_space, file=datfile)

    print(f"@data_no = {i}", file=debugfile)
    print(f"Month: {Month:02d}, Day: {Day:02d}, A: {A:04d}, B: {B:04d}, C: {C:04d}, D: {D:04d}", file=debugfile)
