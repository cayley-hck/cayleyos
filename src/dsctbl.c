#include "bootpack.h"

//初始化GDT和IDT
void init_gdtidt(void)
{
	//设置起始地址
	struct SEGMENT_DESCRIPTOR *gdt = (struct SEGMENT_DESCRIPTOR *) ADR_GDT;
	struct GATE_DESCRIPTOR    *idt = (struct GATE_DESCRIPTOR    *) ADR_IDT;

	int i;

	//GDT初始化
	for (i = 0; i < LIMIT_GDT/8; i++) {
		set_segmdesc(gdt + i, 0, 0, 0);
	}
	set_segmdesc(gdt + 1, 0xffffffff, 0x00000000, AR_DATA32_RW);
	set_segmdesc(gdt + 2, LIMIT_BOTPAK, ADR_BOTPAK, AR_CODE32_ER);
	load_gdtr(LIMIT_GDT, ADR_GDT);

	//IDT初始化
	for (i = 0; i < LIMIT_IDT/8; i++) {
		set_gatedesc(idt + i, 0, 0, 0);
	}
	load_idtr(LIMIT_IDT, ADR_IDT);


	//IDT的设定
	set_gatedesc(idt + 0x21, (int) asm_inthandler21, 2 * 8, AR_INTGATE32);
	set_gatedesc(idt + 0x27, (int) asm_inthandler27, 2 * 8, AR_INTGATE32);
	set_gatedesc(idt + 0x2c, (int) asm_inthandler2c, 2 * 8, AR_INTGATE32);

	return;
}
/*  
	base:段的基址 ->分为low(2个字节),mid(1字节),high(1字节),32位.为了和80286的cpu兼容
	limit:段上限.最大是4GB,分别写到limit_low和limit_high
	ar:段属性,使用ar或者access_right表示
		
*/
void set_segmdesc(struct SEGMENT_DESCRIPTOR *sd, unsigned int limit, int base, int ar)
{
	if (limit > 0xfffff) {
		ar |= 0x8000; /* G_bit = 1 */
		limit /= 0x1000;
	}
	sd->limit_low    = limit & 0xffff; //上限值
	sd->base_low     = base & 0xffff; //低位基址
	sd->base_mid     = (base >> 16) & 0xff; //中位基址
	sd->access_right = ar & 0xff;  //段属性
	sd->limit_high   = ((limit >> 16) & 0x0f) | ((ar >> 8) & 0xf0);//上限值
	sd->base_high    = (base >> 24) & 0xff; //高位基址
	return;
}

void set_gatedesc(struct GATE_DESCRIPTOR *gd, int offset, int selector, int ar)
{
	gd->offset_low   = offset & 0xffff;
	gd->selector     = selector;
	gd->dw_count     = (ar >> 8) & 0xff;
	gd->access_right = ar & 0xff;
	gd->offset_high  = (offset >> 16) & 0xffff;
	return;
}
