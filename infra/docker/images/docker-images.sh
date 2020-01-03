#!/bin/bash

set -e

function usage {
    
    echo "USAGE: $0 [action] [--image-list images.list] [--images images.tar.gz] [--registry registry:port]"
    echo 
    echo "  <action>                        action with docker images: [import, export, remove]"
    echo "  <-l|--images-list path>         text file with list of images; one image per line."
    echo "  <-i|--images-archive path>      tar.gz generated by docker save."
    echo "  <-r|--registry registry:port>   target private registry:port."
    echo "  [-h|--help]                     Usage message"
}

images_remove () {

    IMAGES_LIST=${1:-}

    IMAGES_COUNTER=0
    TOTAL_IMAGES=$(cat ${IMAGES_LIST} | wc -l)

    while IFS= read -r image; do
        [ -z "${image}" ] && continue
        ((IMAGES_COUNTER+=1))
        echo "[INFO] (${IMAGES_COUNTER}/${TOTAL_IMAGES}) Removing docker image: ${image}"
        if ! docker rmi "${image}" > /dev/null 2>&1; then
            echo "[WARNING] Cannot remove docker image: ${image}"
        fi
    done < "${IMAGES_LIST}"

}

images_import () {

    IMAGES_LIST=${1:-}
    IMAGES_ARCHIVE=${2:-}

    IMAGES_COUNTER=0
    TOTAL_IMAGES=$(cat ${IMAGES_LIST} | wc -l)

    echo "[INFO] Importing docker images from ${IMAGES_LIST} to archive: ${IMAGES_ARCHIVE}"

    PULLED_IMAGES=""
    while IFS= read -r image; do
        [ -z "${image}" ] && continue
        ((IMAGES_COUNTER+=1))
        
        echo "[INFO] (${IMAGES_COUNTER}/${TOTAL_IMAGES}) Docker image pulling: ${image}"
        if docker pull "${image}" > /dev/null 2>&1; then
            PULLED_IMAGES="${PULLED_IMAGES} ${image}"
        else
            if docker inspect "${image}" > /dev/null 2>&1; then
                echo "[INFO] Docker image already exists in local repo,${image}"
                PULLED_IMAGES="${PULLED_IMAGES} ${image}"		
            else
                echo "[WARNING] Docker image pulling was failed, ${image}"
                exit 1
            fi
        fi
    done < "${IMAGES_LIST}"

    echo "Creating '${IMAGES_ARCHIVE}' with $(echo ${PULLED_IMAGES} | wc -w | tr -d '[:space:]') images"
    docker save $(echo ${PULLED_IMAGES}) | gzip --stdout > ${IMAGES_ARCHIVE}

}

images_export () {

    REGISTRY=${1:-}
    IMAGES_ARCHIVE=${2:-}
    IMAGES_LIST=${3:-}

    IMAGES_COUNTER=0
    TOTAL_IMAGES=$(cat ${IMAGES_LIST} | wc -l)

    echo "[INFO] Loading docker images from archive '${IMAGES_ARCHIVE}' to local docker repo"
    # docker load --input ${IMAGES_ARCHIVE}

    while IFS= read -r image; do
        [ -z "${image}" ] && continue
        ((IMAGES_COUNTER+=1))
        
        docker tag ${image} $REGISTRY/${image}
        docker push $REGISTRY/${image}

    done < "${IMAGES_LIST}"


    echo "[INFO] Exporting docker images from file '${IMAGES_ARCHIVE}' to registry '${REGISTRY}'"
}


POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        import)
            ACTION="IMPORT"
            shift # pass argument
            ;;
        export)
            ACTION="EXPORT"
            shift # pass argument
            ;;
        remove)
            ACTION="REMOVE"
            shift # pass argument
            ;;
        -i|--images-archive)
            IMAGES_ARCHIVE="$2"
            shift # past argument
            shift # past value
            ;;
        -l|--images-list)
            IMAGES_LIST="$2"
            shift # past argument
            shift # past value
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift # past argument
            shift # past value
            ;;
        -h|--help)
            help="true"
            shift
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [[ $help ]]; then
    usage
    exit 0
fi

if [[ $ACTION == "REMOVE" ]]; then
    [[ -z $IMAGES_LIST ]] && {
        echo "[ERROR] Please specify the file with docker images list"
        exit 1
    }
    images_remove $IMAGES_LIST 

elif [[ $ACTION == "IMPORT" ]]; then
    [[ -z $IMAGES_LIST ]] && {
        echo "[ERROR] Please specify the file with docker images list"
        exit 1
    }
    [[ -z $IMAGES_ARCHIVE ]] && {
        echo "[ERROR] Please specify the archive file"
        exit 1
    }
    images_import $IMAGES_LIST $IMAGES_ARCHIVE

elif [[ $ACTION == "EXPORT" ]]; then

    [[ -z $IMAGES_LIST ]] && {
        echo "[ERROR] Please specify the file with docker images list"
        exit 1
    }
    [[ -z $IMAGES_ARCHIVE ]] && {
        echo "[ERROR] Please specify the archive file"
        exit 1
    }
    [[ -z $REGISTRY ]] && {
        echo "[ERROR] Please specify the registry details"
        exit 1
    }
    images_export $REGISTRY $IMAGES_ARCHIVE $IMAGES_LIST

else
    echo "[ERROR] Unknown action: ${ACTION}"
    exit 1
fi