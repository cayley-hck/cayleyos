; haribote-ipl
; TAB=4

CYLS	EQU		10				; 设置启动区

		ORG		0x7c00			; 指明程序装载到内存的地址

; 以下的记述用户标准的FAT2格式的软盘

		JMP		entry
		DB		0x90
		DB		"HARIBOTE"		; 启动区的名称，可以自定义，必须8个字节
		DW		512				; 每个扇区的大小，必须为512字节
		DB		1				; cluster的大小，必须为1个扇区
		DW		1				; FAT的起始位置，一般从第一个扇区开始
		DB		2				; FAT的个数，必须为2
		DW		224				; 根目录的大小，一般设置为224项
		DW		2880			; 该磁盘的大小，必须为2880扇区
		DB		0xf0			; 磁盘的种类 必须是0xf0
		DW		9				; FAT的长度，必须是9个扇区
		DW		18				; 1个磁道（track）有几个扇区，必须18个
		DW		2				; 磁头数，必须2个
		DD		0				; 不使用分区，必须0
		DD		2880			; 重写一次磁盘大小­
		DB		0,0,0x29		; 意义不明，固定
		DD		0xffffffff		; 卷标号码
		DB		"HARIBOTEOS "	; 磁盘名称，11个字节
		DB		"FAT12   "		; 磁盘格式名称 8个字节
		RESB	18				; 先空出18个字节

; 程序核心

entry:
		MOV		AX,0			; 初始化寄存器
		MOV		SS,AX
		MOV		SP,0x7c00
		MOV		DS,AX

; 读磁盘

		MOV		AX,0x0820
		MOV		ES,AX
		MOV		CH,0			; 柱面0
		MOV		DH,0			; 磁头0
		MOV		CL,2			; 扇区2
readloop:
		MOV		SI,0			; 记录失败次数的寄存器
retry:
		MOV		AH,0x02			; AH=0x02 : 读盘
		MOV		AL,1			; 1个扇区
		MOV		BX,0
		MOV		DL,0x00			; A驱动器
		INT		0x13			; 调用读盘BIOS
		JNC		next			; 没出错的话，就跳转到next
		ADD		SI,1			; 往SI+1
		CMP		SI,5			; 比较SI与5
		JAE		error			; SI >= 5 ，跳转到error
		MOV		AH,0x00
		MOV		DL,0x00			; A驱动器
		INT		0x13			; 重置驱动器
		JMP		retry			; 如果出错不超过5次，就重试
next:
		MOV		AX,ES			; 把内存地址后移0x200
		ADD		AX,0x0020
		MOV		ES,AX			; 因为没有ADD,ES,0x200的指令，所以这个稍微绕个弯
		ADD		CL,1			; 往CL+1
		CMP		CL,18			; 将CL与18比较
		JBE		readloop		; 如果CL <= 18（没有读满18个扇区），就跳转至readloop继续
		MOV		CL,1            ; 读完18个扇区后,继续读下个磁盘,需要将扇区重置为1
		ADD		DH,1            ; 磁头+1，继续读背面
		CMP		DH,2
		JB		readloop		; 如果DH < 2（没有读满两个磁磁盘），就跳转至readloop继续
		MOV		DH,0            ; 重置磁头,读下一个柱面的正面
		ADD		CH,1            ; 柱面+1
		CMP		CH,CYLS
		JB		readloop		; 如果CH < CYLS（如果没有读满10个柱面），就跳转至readloop继续

; 

		MOV		[0x0ff0],CH		; IPL
		JMP		0xc200

error:
		MOV		SI,msg
putloop:
		MOV		AL,[SI]
		ADD		SI,1			; 给SI加1
		CMP		AL,0
		JE		fin
		MOV		AH,0x0e			; 显示一个文字
		MOV		BX,15			; 指定字符颜色
		INT		0x10			; 调用显卡BIOS
		JMP		putloop
fin:
		HLT						; 让cpu停止，等待指令
		JMP		fin				; 无限循环
msg:
		DB		0x0a, 0x0a		; 换行两次
		DB		"load error"
		DB		0x0a			; 换行
		DB		0

		RESB	0x7dfe-$		; 填写0x00,知道0x001fe

		DB		0x55, 0xaa	    ; 之后两个字节必须55 AA ,确保计算机知晓该磁盘上有所需的启动程序
