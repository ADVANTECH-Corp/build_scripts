#!/bin/bash

BUILD_PATH=$1
GIT_TOKEN=$2

echo "-------------------------------------------------"
echo "Build in $0 begin ..."
echo "BUILD_PATH:	${BUILD_PATH}"
echo "GIT_TOKEN :	${GIT_TOKEN}"
DATE_TIME=`date +%Y%m%d%H%M%S`

# bring up docker container
DOCK_ID=$(sudo docker run -itd --name build_rk3568_linux_risc_${DATE_TIME} -v ${BUILD_PATH}:/home/adv/BSP:rw --privileged advrisc/u18.04-rklbv1:latest /bin/bash)


# config git in docker container
sudo docker exec ${DOCK_ID} /bin/bash -c "
git config --global credential.helper 'store --file ~/.my-credentials'; \
echo "${GIT_TOKEN}" > ~/.my-credentials; \
git config --global user.name "advrisc"; \
git config --global user.email "advrisc@gmail.com" "

# build in docker container
sudo docker exec ${DOCK_ID} /bin/bash -c "
sudo chmod a+rw /home/adv/BSP/ -R; \
cd /home/adv/BSP; \
source azure_env.sh; \
./all_rk3568_debian10_v110_risc_officialbuild.sh"

# stop & rm docker container
sudo docker stop ${DOCK_ID}
sudo docker rm ${DOCK_ID}

echo "Build in $0 end"
echo "-------------------------------------------------"


