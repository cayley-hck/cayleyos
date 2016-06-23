; haribote-os boot asm
; TAB=4

BOTPAK	EQU		0x00280000		; bootpack
DSKCAC	EQU		0x00100000		; 
DSKCAC0	EQU		0x00008000		; 

; 关于BOOT_INFO
CYLS	EQU		0x0ff0			; 设置启动区
LEDS	EQU		0x0ff1
VMODE	EQU		0x0ff2			; 关于颜色数目的信息.颜色的位数
SCRNX	EQU		0x0ff4			; 分辨率的X(screen x)
SCRNY	EQU		0x0ff6			; 分辨率的Y(screen y)
VRAM	EQU		0x0ff8			; 图像缓冲区的开始地址

		ORG		0xc200			; 这个程序将要被内存装载的地方

; 

		MOV		AL,0x13			; VGA显卡,320*200*8位彩色
		MOV		AH,0x00
		INT		0x10
		MOV		BYTE [VMODE],8	; 记录画面模式
		MOV		WORD [SCRNX],320
		MOV		WORD [SCRNY],200
		MOV		DWORD [VRAM],0x000a0000

; 用BIOS取得键盘上各种LED指示灯的状态

		MOV		AH,0x02
		INT		0x16 			; keyboard BIOS
		MOV		[LEDS],AL

; PIC关闭一切中断
;	根据AT兼容机的规格,如果要初始化PIC,就必须在CLI之前.否则会被挂起.	
;	先禁止cpu级别的中断,才能进行PIC初始化

		MOV		AL,0xff
		OUT		0x21,AL         ;io_out(PIC0_IMR, 0xff); 􏶙禁止主PIC的􏶜全部中断􏵽
		NOP						; 有些机器无法连续执行OUT指令
		OUT		0xa1,AL         ;io_out(PIC1_IMR, 0xff); /禁止从PIC的􏶜全部中断

		CLI						; 禁止CPU级别的中断

; 设置A2OGATE,使CPU能够访问1MB意思的内存空间
; 往键盘控制电路的附属端口发送指令0xdf,因为这个端口连接主板上的很多地方
; 是让A20GATE电路打开可以让cpu使用1MB以上内存

		CALL	waitkbdout		;相当于wait_KBC_sendready();等待设备能够响应的cpu的指令
		MOV		AL,0xd1
		OUT		0x64,AL
		CALL	waitkbdout
		MOV		AL,0xdf			; enable A20
		OUT		0x60,AL         ; 输出0xdf,是让A20GATE信号线变成ON状态
		CALL	waitkbdout		; 等待是让A20GATE的处理完成

; 切换到保护模式

[INSTRSET "i486p"]				; 想要使用486指令的叙述

		LGDT	[GDTR0]			; 装入临时GDT
		MOV		EAX,CR0
		AND		EAX,0x7fffffff	; 设bit31为0(为了禁止版)
		OR		EAX,0x00000001	; 设bit0为1(为了切换到保护模式)
		MOV		CR0,EAX
		JMP		pipelineflush
pipelineflush:
		MOV		AX,1*8			;  可读写的段 32bit
		MOV		DS,AX
		MOV		ES,AX
		MOV		FS,AX
		MOV		GS,AX
		MOV		SS,AX

; bootpack的传送

		MOV		ESI,bootpack	; 传送源
		MOV		EDI,BOTPAK		; 传送目的地 
		MOV		ECX,512*1024/4
		CALL	memcpy

;  磁盘数据最终转送到它的位置去 

; 首先从启动扇区开始
; DSKCAC是0x00100000 ,从0x7c00复制512字节到0x00100000
; 想启动扇区复制到1MB以后的内存中去


		MOV		ESI,0x7c00		; 转送源 
		MOV		EDI,DSKCAC		; 转送目的地 
		MOV		ECX,512/4       ; 传送数据大小是以双字节为单位,所以数据大小用字节数除以4
		CALL	memcpy

; 所有剩下的 ,将从0x00008200的磁盘内容复制到0x00100200去

		MOV		ESI,DSKCAC0+512	; 转送源 
		MOV		EDI,DSKCAC+512	; 转送目的地 
		MOV		ECX,0
		MOV		CL,BYTE [CYLS]
		IMUL	ECX,512*18*2/4	; 从柱面数变换为字节数/4 
		SUB		ECX,512/4		; 减去IPL 
		CALL	memcpy

; 必须有asmhead来完成的工作,到这里就全部完毕
;	以后就交由bootpack来完成

; bootpack的启动

		MOV		EBX,BOTPAK
		MOV		ECX,[EBX+16]    ; bootpack.hrb之后的第16号地址 ,0x11a8
		ADD		ECX,3			; ECX += 3;
		SHR		ECX,2			; ECX /= 4;
		JZ		skip			; 没有要转送的东西时 
		MOV		ESI,[EBX+20]	; 转送源 ,bootpack.hrb之后的第20号地址 ,0x10c8
		ADD		ESI,EBX
		MOV		EDI,[EBX+12]	; 转送目的地 ,bootpack.hrb之后的第12号地址 ,0x00310000
		CALL	memcpy
skip:
		MOV		ESP,[EBX+12]	; 栈初始值
		JMP		DWORD 2*8:0x0000001b

;相当于wait_KBC_sendready
waitkbdout:
		IN		 AL,0x64
		AND		 AL,0x02
		JNZ		waitkbdout		; AND的结果如果不是0,就跳转到waitkbdout
		RET
;memcpy(􏸜􏳰􏹇􏰸􏹈转送源地址,转送目的地址,转送数据大小)
memcpy:
		MOV		EAX,[ESI]
		ADD		ESI,4
		MOV		[EDI],EAX
		ADD		EDI,4
		SUB		ECX,1
		JNZ		memcpy			; 减法运算的结果如果不是0,就跳转的memcpy
		RET
;ALIGNB指令,一直条件DBO,直到地址被16整除
		ALIGNB	16
;GDT0也是一种特殊的GDT,0号是空区域(null sector) ,不能再0号定义段
GDT0:
		RESB	8				
		DW		0xffff,0x0000,0x9200,0x00cf	;写入32位的段起始地址
		DW		0xffff,0x0000,0x9a28,0x0047	;写入16位段上限 

		DW		0

;GDTR0是LGDT指令,通知GDT0,有GDT了
GDTR0:
		DW		8*3-1
		DD		GDT0

		ALIGNB	16
bootpack:
