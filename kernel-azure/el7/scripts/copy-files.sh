#!/bin/bash

[ ! -z "$1" ] || { echo "Error: copy-files: kversion undefined" ; exit 1; }
[ ! -z "$2" ] || { echo "Error: copy-files: lisdir undefined" ; exit 1; }

kversion="${1}"
lisdir="${2}"

topdir="/mnt/resource/CENTOS-KERNEL"
lisdir="${topdir}/${lisdir}/hv-rhel7.x/hv"
kerndir="${topdir}/linux-${kversion}.lis"

# Fixup headers for /linux/arch components
# We isolate everything in arch since LIS does not touch these files

 # arch/x86/kernel/cpu/
 cp ${kerndir}/arch/x86/include/asm/mshyperv.h			${kerndir}/arch/x86/kernel/cpu/mshyperv.h
 cp ${kerndir}/arch/x86/include/uapi/asm/hyperv.h		${kerndir}/arch/x86/kernel/cpu/hyperv.h

 sed -i 's/<asm\/hyperv\.h>/"hyperv.h"/g'			${kerndir}/arch/x86/kernel/cpu/mshyperv.h

 sed -i 's/<asm\/hyperv\.h>/"hyperv.h"/g'			${kerndir}/arch/x86/kernel/cpu/mshyperv.c
 sed -i 's/<asm\/mshyperv\.h>/"mshyperv.h"/g'			${kerndir}/arch/x86/kernel/cpu/mshyperv.c

 # arch/x86/hyperv/
 # hv_init.c and mmu.c
 mkdir -p ${kerndir}/arch/x86/hyperv/include/linux/uapi
 mkdir -p ${kerndir}/arch/x86/hyperv/include/asm/trace

 cp ${kerndir}/arch/x86/include/asm/mshyperv.h			${kerndir}/arch/x86/hyperv/include/asm/mshyperv.h
 cp ${kerndir}/arch/x86/include/uapi/asm/hyperv.h		${kerndir}/arch/x86/hyperv/include/asm/hyperv.h
 cp ${kerndir}/arch/x86/include/asm/trace/hyperv.h		${kerndir}/arch/x86/hyperv/include/asm/trace/hyperv.h
 cp ${kerndir}/include/linux/hyperv.h				${kerndir}/arch/x86/hyperv/include/linux/hyperv.h
 cp ${kerndir}/include/uapi/linux/hyperv.h			${kerndir}/arch/x86/hyperv/include/linux/uapi/hyperv.h
 
 sed -i 's/<uapi\/linux\/hyperv\.h>/"uapi\/hyperv.h"/g'		${kerndir}/arch/x86/hyperv/include/linux/hyperv.h
 sed -i 's/<uapi\/asm\/hyperv\.h>/"..\/asm\/hyperv.h"/g'	${kerndir}/arch/x86/hyperv/include/linux/hyperv.h
 sed -i 's/<asm\/hyperv\.h>/"hyperv.h"/g'			${kerndir}/arch/x86/hyperv/include/asm/mshyperv.h

 sed -i 's/<asm\/hyperv\.h>/"include\/asm\/hyperv.h"/g'		${kerndir}/arch/x86/hyperv/hv_init.c
 sed -i 's/<asm\/mshyperv\.h>/"include\/asm\/mshyperv.h"/g'	${kerndir}/arch/x86/hyperv/hv_init.c
 sed -i 's/<linux\/hyperv\.h>/"include\/linux\/hyperv.h"/g'	${kerndir}/arch/x86/hyperv/hv_init.c

 sed -i 's/<linux\/hyperv\.h>/"include\/linux\/hyperv.h"/g'		${kerndir}/arch/x86/hyperv/mmu.c
 sed -i 's/<asm\/mshyperv\.h>/"include\/asm\/mshyperv.h"/g'		${kerndir}/arch/x86/hyperv/mmu.c
 sed -i 's/<asm\/trace\/hyperv\.h>/"include\/asm\/trace\/hyperv.h"/g'	${kerndir}/arch/x86/hyperv/mmu.c

 # vclock_gettime.c, kvm_para.h, hvm_host.h
 sed -i 's/<asm\/mshyperv\.h>/"..\/hyperv\/include\/asm\/mshyperv.h"/g'		${kerndir}/arch/x86/vdso/vclock_gettime.c
 sed -i 's/<asm\/hyperv\.h>/"..\/..\/..\/hyperv\/include\/asm\/hyperv.h"/g'	${kerndir}/arch/x86/include/uapi/asm/kvm_para.h
 sed -i 's/<linux\/hyperv\.h>/"..\/..\/hyperv\/include\/linux\/hyperv.h"/g'	${kerndir}/arch/x86/include/asm/kvm_host.h


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
 sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/g'		${kerndir}/drivers/hv/hv_init.c
 sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/g'		${kerndir}/drivers/hv/hv_init.c

 cp ${lisdir}/arch/x86/hyperv/ms_hyperv_ext.c			${kerndir}/drivers/hv/ms_hyperv_ext.c
 sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/g'		${kerndir}/drivers/hv/ms_hyperv_ext.c
 sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/g'		${kerndir}/drivers/hv/ms_hyperv_ext.c

 # Fix hv_trace_balloon.h TRACE_INCLUDE_PATH
 sed -i 's/TRACE_INCLUDE_PATH \./TRACE_INCLUDE_PATH ..\/..\/drivers\/hv/'	${kerndir}/drivers/hv/hv_trace_balloon.h

sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/g'		${kerndir}/drivers/hv/channel_mgmt.c
sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/g'			${kerndir}/drivers/hv/connection.c
sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/g'		${kerndir}/drivers/hv/connection.c
sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/g'			${kerndir}/drivers/hv/hv.c
sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/g'		${kerndir}/drivers/hv/hv.c
sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/g'		${kerndir}/drivers/hv/hv_util.c
sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/g'			${kerndir}/drivers/hv/vmbus_drv.c
sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/g'		${kerndir}/drivers/hv/vmbus_drv.c

for i in ${kerndir}/drivers/hv/*; do
	sed -ri 's/"(\.\/)?include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g' $i
done


# hv_netvsc
cp ${lisdir}/hyperv_net.h					${kerndir}/drivers/net/hyperv/hyperv_net.h
cp ${lisdir}/netvsc_compat.h					${kerndir}/drivers/net/hyperv/netvsc_compat.h
cp ${lisdir}/netvsc.c						${kerndir}/drivers/net/hyperv/netvsc.c
cp ${lisdir}/netvsc_trace.h					${kerndir}/drivers/net/hyperv/netvsc_trace.h
cp ${lisdir}/netvsc_drv.c					${kerndir}/drivers/net/hyperv/netvsc_drv.c
cp ${lisdir}/rndis_filter.c					${kerndir}/drivers/net/hyperv/rndis_filter.c

sed -ri 's/"(\.\/)?include\/linux\/rndis\.h"/<linux\/rndis\.h>/g' ${kerndir}/drivers/net/hyperv/hyperv_net.h

for i in ${kerndir}/drivers/net/hyperv/*; do
	 sed -ri 's/"(\.\/)?include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g' $i
done


# vmsock
cp ${lisdir}/hyperv_transport.c					${kerndir}/net/vmw_vsock/hyperv_transport.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g'	${kerndir}/net/vmw_vsock/hyperv_transport.c


# hv_storvsc
cp ${lisdir}/storvsc_drv.c					${kerndir}/drivers/scsi/storvsc_drv.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g'	${kerndir}/drivers/scsi/storvsc_drv.c


# Hyper-V HID
cp ${lisdir}/hid-hyperv.c					${kerndir}/drivers/hid/hid-hyperv.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g'	${kerndir}/drivers/hid/hid-hyperv.c


# hv_pci
cp ${lisdir}/pci-hyperv.c					${kerndir}/drivers/pci/pci-hyperv.c
sed -i 's/lis\/asm\/mshyperv\.h/asm\/mshyperv\.h/g'		${kerndir}/drivers/pci/pci-hyperv.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g'	${kerndir}/drivers/pci/pci-hyperv.c


# Hyper-V FB
cp ${lisdir}/hyperv_fb.c					${kerndir}/drivers/video/hyperv_fb.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g'	${kerndir}/drivers/video/hyperv_fb.c


# Hyper-V Keyboard
cp ${lisdir}/hyperv-keyboard.c					${kerndir}/drivers/input/serio/hyperv-keyboard.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g'	${kerndir}/drivers/input/serio/hyperv-keyboard.c


# Hyper-V UIO
cp ${lisdir}/uio_hv_generic.c					${kerndir}/drivers/uio/uio_hv_generic.c
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g'	${kerndir}/drivers/uio/uio_hv_generic.c
cp ${lisdir}/hyperv_vmbus.h					${kerndir}/drivers/uio/hyperv_vmbus.h
sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g'	${kerndir}/drivers/uio/hyperv_vmbus.h
cp ${lisdir}/hv_trace.h						${kerndir}/drivers/uio/hv_trace.h


# Hyper-V network-direct
#${lisdir}/hvnd_addr.c
#${lisdir}/mx_abi.h
#${lisdir}/provider.c
#${lisdir}/vmbus_rdma.c
#${lisdir}/vmbus_rdma.h
#sed -i 's/"include\/linux\/hyperv\.h"/<linux\/hyperv\.h>/g'


# Headers
cp ${lisdir}/arch/x86/include/lis/asm/mshyperv.h		${kerndir}/arch/x86/include/asm/mshyperv.h
cp ${lisdir}/arch/x86/include/uapi/lis/asm/hyperv.h		${kerndir}/arch/x86/include/uapi/asm/hyperv.h
cp ${lisdir}/include/uapi/linux/hyperv.h			${kerndir}/include/uapi/linux/hyperv.h
cp ${lisdir}/include/linux/hyperv.h				${kerndir}/include/linux/hyperv.h
cp ${lisdir}/include/linux/hv_compat.h				${kerndir}/include/linux/hv_compat.h

sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/g'			${kerndir}/arch/x86/include/asm/mshyperv.h
sed -i 's/lis\/asm\/hyperv\.h/asm\/hyperv\.h/g'			${kerndir}/include/linux/hyperv.h


# Copy any fixed Makefile and Kconfig files
cp ./Makefile-drivers_hv					${kerndir}/drivers/hv/Makefile

