#!/bin/bash

# CentOS6
## Note: Does not yet include vmsock

[ ! -z "$1" ] || { echo "Error: copy-files: kversion undefined" ; exit 1; }
[ ! -z "$2" ] || { echo "Error: copy-files: lisdir undefined" ; exit 1; }

kversion="${1}"
lisdir="${2}"

topdir="/mnt/resource/CENTOS-KERNEL"
lisdir="/home/ostc/CENTOS-KERNEL/${lisdir}/hv-rhel6.x/hv"
kerndir="/home/ostc/CENTOS-KERNEL/linux-${kversion}.lis"

# Fixup mshyperv.c headers
sed -i 's/<asm\/hyperv\.h>/"hyperv.h"/'				${kerndir}/arch/x86/kernel/cpu/mshyperv.c
sed -i 's/<asm\/mshyperv\.h>/"mshyperv.h"/'			${kerndir}/arch/x86/kernel/cpu/mshyperv.c
cp ${kerndir}/arch/x86/include/asm/mshyperv.h			${kerndir}/arch/x86/kernel/cpu/mshyperv.h
cp ${kerndir}/arch/x86/include/asm/hyperv.h			${kerndir}/arch/x86/kernel/cpu/hyperv.h


# hv_vmbus
cp ${lisdir}/channel.c						${kerndir}/drivers/hv/channel.c
cp ${lisdir}/channel_mgmt.c					${kerndir}/drivers/hv/channel_mgmt.c
cp ${lisdir}/connection.c					${kerndir}/drivers/hv/connection.c
cp ${lisdir}/hv_balloon.c					${kerndir}/drivers/hv/hv_balloon.c
cp ${lisdir}/hv_trace_balloon.h					${kerndir}/drivers/hv/hv_trace_balloon.h
cp ${lisdir}/hv.c						${kerndir}/drivers/hv/hv.c
cp ${lisdir}/hv_fcopy.c						${kerndir}/drivers/hv/hv_fcopy.c
cp ${lisdir}/hv_kvp.c						${kerndir}/drivers/hv/hv_kvp.c
cp ${lisdir}/hv_util.c						${kerndir}/drivers/hv/hv_util.c
cp ${lisdir}/hv_snapshot.c					${kerndir}/drivers/hv/hv_snapshot.c
cp ${lisdir}/hv_utils_transport.c				${kerndir}/drivers/hv/hv_utils_transport.c
cp ${lisdir}/hv_utils_transport.h				${kerndir}/drivers/hv/hv_utils_transport.h
cp ${lisdir}/hyperv_vmbus.h					${kerndir}/drivers/hv/hyperv_vmbus.h
cp ${lisdir}/ring_buffer.c					${kerndir}/drivers/hv/ring_buffer.c
cp ${lisdir}/vmbus_drv.c					${kerndir}/drivers/hv/vmbus_drv.c
cp ${lisdir}/hv_trace.c						${kerndir}/drivers/hv/hv_trace.c
cp ${lisdir}/hv_trace.h						${kerndir}/drivers/hv/hv_trace.h

 # Moving these from arch/x86/hyperv to build correctly. Only vmbus requires them anyway
 cp ${lisdir}/arch/x86/hyperv/hv_init.c				${kerndir}/drivers/hv/hv_init.c
 sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/'		${kerndir}/drivers/hv/hv_init.c
 sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/'			${kerndir}/drivers/hv/hv_init.c

 cp ${lisdir}/arch/x86/hyperv/ms_hyperv_ext.c			${kerndir}/drivers/hv/ms_hyperv_ext.c
 sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/'		${kerndir}/drivers/hv/ms_hyperv_ext.c
 sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/'			${kerndir}/drivers/hv/ms_hyperv_ext.c

sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/'	${kerndir}/drivers/hv/channel_mgmt.c
sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/'		${kerndir}/drivers/hv/connection.c
sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/'	${kerndir}/drivers/hv/connection.c
sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/'		${kerndir}/drivers/hv/hv.c
sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/'	${kerndir}/drivers/hv/hv.c
sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/'	${kerndir}/drivers/hv/hv_util.c
sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/' 		${kerndir}/drivers/hv/vmbus_drv.c
sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/'	${kerndir}/drivers/hv/vmbus_drv.c

for i in ${kerndir}/drivers/hv/*; do
	sed -ri 's/"(\.\/)?include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/' $i
	sed -i 's/"include\/uapi\/linux\/hyperv.h"/<uapi\/linux\/hyperv.h>/' $i
done

# Fix drivers/hv/hv_trace_balloon.h
sed -i 's/TRACE_INCLUDE_PATH \./TRACE_INCLUDE_PATH ..\/..\/drivers\/hv/'	 ${kerndir}/drivers/hv/hv_trace_balloon.h


# hv_netvsc
cp ${lisdir}/hyperv_net.h					${kerndir}/drivers/net/hyperv/hyperv_net.h
cp ${lisdir}/netvsc.c						${kerndir}/drivers/net/hyperv/netvsc.c
cp ${lisdir}/netvsc_drv.c					${kerndir}/drivers/net/hyperv/netvsc_drv.c
cp ${lisdir}/rndis_filter.c					${kerndir}/drivers/net/hyperv/rndis_filter.c

sed -ri 's/"(\.\/)?include\/linux\/rndis\.h"/<linux\/rndis\.h>/' ${kerndir}/drivers/net/hyperv/hyperv_net.h

for i in ${kerndir}/drivers/net/hyperv/*; do
	 sed -ri 's/"(\.\/)?include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/' $i
done


# hv_storvsc
cp ${lisdir}/storvsc_drv.c					${kerndir}/drivers/scsi/storvsc_drv.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/'	${kerndir}/drivers/scsi/storvsc_drv.c


# pci-hyperv
#cp ${lisdir}/pci-hyperv.c					${kerndir}/drivers/pci/pci-hyperv.c
#sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/'	${kerndir}/drivers/pci/pci-hyperv.c
#sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/'			${kerndir}/drivers/pci/pci-hyperv.c
#sed -i 's/hyperv_vmbus\.h/\.\.\/hv\/hyperv_vmbus\.h/'		${kerndir}/drivers/pci/pci-hyperv.c


# Hyper-V HID
cp ${lisdir}/hid-hyperv.c					${kerndir}/drivers/hid/hid-hyperv.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/'	${kerndir}/drivers/hid/hid-hyperv.c


# Hyper-V FB
cp ${lisdir}/hyperv_fb.c					${kerndir}/drivers/video/hyperv_fb.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/'	${kerndir}/drivers/video/hyperv_fb.c


# Hyper-V Keyboard
cp ${lisdir}/hyperv-keyboard.c					${kerndir}/drivers/input/serio/hyperv-keyboard.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/'	${kerndir}/drivers/input/serio/hyperv-keyboard.c


# Hyper-V UIO
cp ${lisdir}/uio_hv_generic.c					${kerndir}/drivers/uio/uio_hv_generic.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/'	${kerndir}/drivers/uio/uio_hv_generic.c
cp ${lisdir}/hyperv_vmbus.h					${kerndir}/drivers/uio/hyperv_vmbus.h
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/'	${kerndir}/drivers/uio/hyperv_vmbus.h
cp ${lisdir}/hv_trace.h						${kerndir}/drivers/uio/hv_trace.h


# Hyper-V network-direct
#${lisdir}/hvnd_addr.c
#${lisdir}/mx_abi.h
#${lisdir}/provider.c
#${lisdir}/vmbus_rdma.c
#${lisdir}/vmbus_rdma.h
#sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/'


# Headers
cp ${lisdir}/arch/x86/include/lis/asm/mshyperv.h		${kerndir}/arch/x86/include/asm/mshyperv.h
cp ${lisdir}/arch/x86/include/uapi/lis/asm/hyperv.h		${kerndir}/arch/x86/include/asm/hyperv.h
sed -i 's/"uuid\.h"/<linux\/uuid\.h>/'				${kerndir}/arch/x86/include/asm/hyperv.h

cp ${lisdir}/include/linux/hyperv.h				${kerndir}/include/linux/hyperv.h
cp ${lisdir}/include/linux/hv_compat.h				${kerndir}/include/linux/hv_compat.h

mkdir ${kerndir}/include/uapi/linux
cp ${lisdir}/include/uapi/linux/hyperv.h			${kerndir}/include/uapi/linux/hyperv.h
sed -i 's/"uuid\.h"/<linux\/uuid\.h>/'				${kerndir}/include/uapi/linux/hyperv.h

sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/'			${kerndir}/arch/x86/include/asm/mshyperv.h
sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/'			${kerndir}/include/linux/hyperv.h


# Copy fixed Makefile and Kconfig files
cp ./patches/Makefile-drivers_hv				${kerndir}/drivers/hv/Makefile

#echo							>>	${kerndir}/drivers/pci/Makefile
#echo 'obj-$(CONFIG_PCI_HYPERV) += pci-hyperv.o' 	>>	${kerndir}/drivers/pci/Makefile
#cat <<EOF						>>	${kerndir}/drivers/pci/Kconfig
#
#config PCI_HYPERV
#        tristate "Hyper-V PCI Frontend"
#        depends on PCI && X86 && HYPERV && PCI_MSI && X86_64
#        help
#          The PCI device frontend driver allows the kernel to import arbitrary
#          PCI devices from a PCI backend to support PCI driver domains.
#
#EOF

