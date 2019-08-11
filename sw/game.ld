SECTIONS
{
  . = 0x00000000;
  .ROM :
  {
    *(.text)
    *(.rodata)
  }

  . = 0x10000000;
  .RAM :
  {
    *(.bss)
    *(.data)
  }
}
