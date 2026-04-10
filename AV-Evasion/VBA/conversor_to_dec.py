with open("met64_aes_num.txt", "r") as f:
    data = f.read().replace(" ", "").replace("\n", "")
    
# Converte hex (0xAA, 0xBB) para decimal
hex_list = data.split(",")
dec_list = [str(int(h, 16)) for h in hex_list if h]

print("buf = Array(" + ", ".join(dec_list) + ")")
