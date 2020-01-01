pause:
  push ax
  mov ah, 0
  int 0x16
  pop ax
  ret
