#!/bin/bash

CWD=$(pwd)
REPO="https://github.com/kubernetes/kubernetes.github.io"
ONLINE_URL="http://kubernetes.io/docs/"
DOCSET_NAME="Kubernetes"
BUILD_DIR=${CWD}/build

_usage() {
	cat <<EOF
usage: $0 docset|lists

Commands:
  docset    generates a new Dash docset
  lists     generates ToC lists to update the dashing.json file

Environment Variables:
  VERSION   release of the kubernetes docs to build (optional)
  NOCLEAN   do not clean the build dir (useful for debugging)

EOF
}

_check_deps() {
  which git || { echo "Must have git installed"; exit 1; }
  which wget || { echo "Must have wget installed"; exit 1; }
  which jekyll || { echo "Must have jekyll installed"; exit 1; }
  [ -x /usr/libexec/PlistBuddy ] || { echo "Must have PlistBuddy available"; exit 1; }
}

_new_workspace() {
  # clean workspace
  [ -d ${CWD}/build ] && rm -Rf ${CWD}/build
  mkdir ${CWD}/build

  # remove previous artifacts
  rm -Rf ${CWD}/*.tar.gz ${CWD}/*.docset
}

_download_build_deps() {
  # download patched dashing cli
  wget -O ${BUILD_DIR}/dashing https://github.com/nextrevision/dashing/releases/download/0.3.0-patch/dashing
  chmod +x ${BUILD_DIR}/dashing

  # download doc parser
  wget -O ${BUILD_DIR}/kubernetes-doc-parser https://github.com/nextrevision/kubernetes-doc-parser/releases/download/0.1.0/kubernetes-doc-parser
  chmod +x ${BUILD_DIR}/kubernetes-doc-parser
}

_checkout_docs() {
  # clone source
  git clone $REPO ${BUILD_DIR}/src
  cd ${BUILD_DIR}/src

  # ensure version is set
  if [ -z $VERSION ]; then
    git fetch --all
    select version in $(git branch -a | grep 'remotes/origin/release-' | sed 's#  remotes/origin/release-##g'); do
      VERSION=$version
      break
    done
  fi

  if ! git branch -a | grep -q "release-${VERSION}"; then
    echo "No such version: ${VERSION}"
    exit 1
  fi

  git checkout release-${VERSION}

  cd ${CWD}
}

_create_mirror() {
  jekyll serve -B \
    --config ${BUILD_DIR}/src/_config.yml \
    -d ${BUILD_DIR}/src/_site \
    -s ${BUILD_DIR}/src

  wget -q --mirror -p -l0 -r -P ${BUILD_DIR} \
    --convert-links \
    --page-requisites \
    --adjust-extension \
    http://localhost:4000/docs/ || true

  pkill -f jekyll
  rm -Rf ${CWD}/.sass-cache
}

_docset_build() {
  cd ${BUILD_DIR}/localhost:4000/

  ${BUILD_DIR}/dashing build -f $CWD/dashing.json

  mv kubernetes.docset ${CWD}/

  cd ${CWD}

  cp icon* kubernetes.docset/

  # tar results
  tar --exclude='.DS_Store' -cvzf "${DOCSET_NAME// /_}.tgz" "${DOCSET_NAME}.docset"

  # display results
  echo "Created ${DOCSET_NAME// /_}.tgz"
  echo "Version: ${VERSION}"
}

_generate_toc_lists() {
  [ -d ${CWD}/lists ] || mkdir ${CWD}/lists

  # generate glossary list
  ${BUILD_DIR}/kubernetes-doc-parser \
    -path ${BUILD_DIR}/localhost\:4000/docs/api-reference/v1/definitions.1.html \
    -pattern 'div[data-title="Glossary"] a.item' \
    -ignore '^http' \
    -replace-pattern "^\.\.\/\.\.\/" \
    -replace-string "docs/" &> ${CWD}/lists/glossary.json

  # generate guides
  ${BUILD_DIR}/kubernetes-doc-parser \
    -path ${BUILD_DIR}/localhost\:4000/docs/index.html \
    -pattern '#encyclopedia #docsToc a' \
    -ignore '(^https|docs\/$|docs\/(admin|getting-started-guides|user-guide)\/$|^index.html$)' \
    -replace-pattern "^" \
    -replace-string "docs/" &> ${CWD}/lists/guides.json

  # generate commands
  ${BUILD_DIR}/kubernetes-doc-parser \
    -path ${BUILD_DIR}/localhost\:4000/docs/user-guide/kubectl/kubectl.1.html \
    -pattern 'div[data-title="kubectl Commands"] a.item' \
    -replace-pattern "^" \
    -replace-string "docs/user-guide/kubectl/" &> ${CWD}/lists/commands.json
}

_cleanup() {
  # cleanup
  [ -z $NOCLEAN ] && rm -Rf ${BUILD_DIR}
}

# basic variable checking
[ -z $1 ] && { _usage; exit 1; }
if [[ $1 != "docset" ]] && [[ $1 != "lists" ]]; then
  _usage
  exit 1
fi

set -o errexit
set -o pipefail

if [[ $1 == "docset" ]]; then
  _check_deps
  _new_workspace
  _download_build_deps
  _checkout_docs
  _create_mirror
  _docset_build
  _cleanup
elif [[ $1 == "lists" ]]; then
  _check_deps
  _new_workspace
  _download_build_deps
  _checkout_docs
  _create_mirror
  _generate_toc_lists
  _cleanup
else
  _usage
  exit
fi
