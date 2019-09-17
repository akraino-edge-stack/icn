DIRNAME=`dirname $0`
DOCKER_BUILD_DIR=`cd $DIRNAME/; pwd`
echo "DOCKER_BUILD_DIR=${DOCKER_BUILD_DIR}"
cd ${DOCKER_BUILD_DIR}

IMAGE_NAME="haibinhu/httpd"

function build_image {
    docker build -t ${IMAGE_NAME} .
}

function push_image {
    docker push ${IMAGE_NAME}
}

build_image
push_image
