#-v /lib/modules:/lib/modules --cap-add CAP_SYS_MODULE 
#docker run --rm -it --privileged -v /lib/modules:/lib/modules --cap-add CAP_SYS_MODULE --net host aps /bin/bash

docker build -t wifichallengelab-docker-clients  .
docker run --name clients--rm -it --privileged -v /lib/modules:/lib/modules  --net host ifichallengelab-docker-clients 
