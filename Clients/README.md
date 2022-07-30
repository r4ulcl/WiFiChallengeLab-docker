#-v /lib/modules:/lib/modules --cap-add CAP_SYS_MODULE 
#docker run --rm -it --privileged -v /lib/modules:/lib/modules --cap-add CAP_SYS_MODULE --net host aps /bin/bash

docker build -t clients  .
docker run --name clients--rm -it --privileged -v /lib/modules:/lib/modules  --net host clients
