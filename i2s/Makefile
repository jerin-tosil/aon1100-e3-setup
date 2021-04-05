snd-soc-aon1100e3-objs := aon1100e3.o

obj-m += snd-soc-aon1100e3.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

install:
	sudo cp snd-soc-aon1100e3.ko /lib/modules/$(shell uname -r)/kernel/sound/soc/codecs/
	sudo depmod -a
