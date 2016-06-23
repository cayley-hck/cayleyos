	
#include "bootpack.h"

struct FIFO8 mousefifo;
//鼠标中断
void inthandler2c(int *esp)
{
	unsigned char data;
	io_out8(PIC1_OCW2, 0x64); //通知PIC1 IRQ-12的受理已经完成
	io_out8(PIC0_OCW2, 0x62);	//通知PIC0 IRQ-02的受理已经完成
	//鼠标和键盘都是从0x0060处获取输入数据,这是因为键盘控制电路中含有鼠标的控制电路,
	//若要区分数据来自键盘还是鼠标,只能通过中断号码来区分
	//保存在鼠标缓冲区
	data = io_in8(PORT_KEYDAT);
	fifo8_put(&mousefifo, data);

	return;
}

#define KEYCMD_SENDTO_MOUSE		0xd4
#define MOUSECMD_ENABLE			0xf4

void enable_mouse(struct MOUSE_DEC *mdec){
		//激活鼠标,如果往键盘发送数据0xd4,x下一个数据就会自动发送给鼠标,通过这个特性就可以激活鼠标
		wait_KBC_Sendready();
		io_out8(PORT_KEYCMD,KEYCMD_SENDTO_MOUSE);
		wait_KBC_Sendready();
		io_out8(PORT_KEYDAT,MOUSECMD_ENABLE);

		//键盘控制会返回ACK(0xfa)
		mdec->phase = 0; //激活完成,等待阶段
		return ;
}

int mouse_decode(struct MOUSE_DEC *mdec , unsigned char dat){
		//鼠标数据解码
		if(mdec->phase == 0){
			//等待oxfa阶段
			if(dat == 0xfa){
				mdec->phase = 1;
			}
			return 0;

		}

		if(mdec->phase == 1){
			//等待第一字节
			//缓存第一字节,默认08,(移动鼠标)第一位会在0-3变化,(左右点击,点击中间滑轮)第二位值8-F变化,
			if((dat & 0xc8) == 0x08){ //数值正确,0-3
				mdec->buf[0] = dat;
				mdec->phase = 2;

			}
			return 0;
		}

		if(mdec->phase ==2){
			//等待第二字节
			//缓存第二字节,与鼠标左右移动有关系
			mdec->buf[1] = dat;
			mdec->phase = 3;
			return 0;
		}
		if (mdec->phase == 3){
			//等待第三字节
			//缓存第三字节,与鼠标上下移动有关系
			mdec->buf[2] = dat;
			//重置
			mdec->phase =1;

			mdec->btn = mdec->buf[0] & 0x07; //取出低三位的值
			
			mdec->x = mdec->buf[1];
			mdec->y = mdec->buf[2];

			/*
			复习:
			&运算,一是取一个位串信息的某几位，如以下代码截取x的最低7位：x & 0177。二是让某变量保留某几位，其余位置0，如以下代码让x只保留最低6位：x = x & 077。以上用法都先要设计好一个常数，该常数只有需要的位是1，不需要的位是0。用它与指定的位串信息按位与
			|运算,将一个位串信息的某几位置成1。
			*/
			if((mdec->buf[0] & 0x10) !=0){
				mdec->x |= 0xffffff00;//第八位及以后的,设置为1或者0,这样正确解读数据
			}
			if((mdec->buf[0] & 0x20) !=0){
				mdec->y |= 0xffffff00;
			}
			mdec->y = -mdec->y;//鼠标的y方向与画面符号相反
			

			return 1;

		}

		return -1 ;//应该不可能到这里来
}

