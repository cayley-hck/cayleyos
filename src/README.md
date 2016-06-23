01day-环境构建:
1.到官网http://hrb.osask.jp,找到mac版环境的地址：http://shrimp.marokun.net/osakkie/wiki/tolsetOSX

2.需要自己安装qemu程序：
brew install qemu

3.需要修改makefile文件:

将要的exe程序名字换为mac版的
将mask run:	$(MAKE) img
	qemu-system-i386 -fda haribote.img


