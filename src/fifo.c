#include "bootpack.h"

#define FLAGS_OVERRUN	0x0001

void fifo8_init(struct FIFO8 *fifo , int size , unsigned char *buf){
	//初始化FIFO缓冲区
	fifo->size = size;
	fifo->buf = buf;
	fifo->free = size;	//空闲==大小
	fifo->flags = 0 ;
	fifo->p = 0;	//下一个s数据写入位置
	fifo->q = 0;	//下一个数据读出位置

	return ;
}

int fifo8_put(struct FIFO8 *fifo , unsigned char data){
	//入队
	if(fifo->free == 0){
		//溢出
		fifo->flags |= FLAGS_OVERRUN;
		return -1;	//溢出
	}

	fifo->buf[fifo->p] = data;
	fifo->p++;
	if(fifo->p == fifo->size){
		fifo->p = 0;
	}

	fifo->free--;
	return 0 ; //没有溢出,正常

}

int fifo8_get(struct FIFO8 *fifo){
	//出队
	int data;
	if(fifo->free == fifo->size){
		//if缓冲区为空,then返回 -1 
		return -1;
	}

	data = fifo->buf[fifo->q];
	fifo->q++;
	if(fifo->q == fifo->size){
		fifo->q = 0;
	}
	fifo->free++;

	return data;
}

int fifo8_status(struct FIFO8 * fifo){
	//返回保存的数据量

	return fifo->size - fifo->free;
}
