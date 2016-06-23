#include "bootpack.h"


struct FIFO8 keyfifo ;

//鼠标和键盘的中断 ,鼠标是IRQ12,键盘是IRQ1
void inthandler21(int *esp){
	unsigned char data;
	//通知PIC,IRQ-01已经受理完毕
	io_out8(PIC0_OCW2,0x61);
	data = io_in8(PORT_KEYDAT);//从编号0x0060的设备输入的8位信息是按键编码,编号为0x0060的设备就是键盘.IBM规定的
	//保存在缓冲区
	fifo8_put(&keyfifo,data);

	return;
}


#define PORT_KEYSTA				0x0064
#define KEYSTA_SEND_NOTREADY	0x02
#define KEYCMD_WRITE_MODE		0x60	//模式设置指令
#define KBC_MODE				0x47	//鼠标模式指令


	void wait_KBC_Sendready(void){
		for(;;){
			//等待键盘的响应,由于cpu运算速度比键盘快好多,如果cpu从设备号码0x0064处
			//读取的数据的倒数第二位(从低位开始的第二位),是零,就表示可以了,已收到键盘信息
			if((io_in8(PORT_KEYSTA) & KEYSTA_SEND_NOTREADY) == 0){
				break;
			}
		}

	}

	void init_keyboard(void){
		//初始化键盘控制器,
		wait_KBC_Sendready();
		io_out8(PORT_KEYCMD,KEYCMD_WRITE_MODE);
		wait_KBC_Sendready();
		io_out8(PORT_KEYDAT,KBC_MODE);
	}
