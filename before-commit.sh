#!/usr/bin/env bash

readonly CI_FLAG=ci

RED='\033[0;31m'
GREEN='\033[0;32m'
INVERTED='\033[7m'
NC='\033[0m' # No Color

echo -e "${INVERTED}"
echo "USER: " + $USER
echo "PATH: " + $PATH
echo "GOPATH:" + $GOPATH
echo -e "${NC}"

##
# DEP ENSURE
##
dep ensure -v --vendor-only
ensureResult=$?
if [ ${ensureResult} != 0 ]; then
	echo -e "${RED}✗ dep ensure -v --vendor-only${NC}\n$ensureResult${NC}"
	exit 1
else echo -e "${GREEN}√ dep ensure -v --vendor-only${NC}"
fi

##
# GO BUILD
##
binaries=("manager")
buildEnv=""
if [ "$1" == "$CI_FLAG" ]; then
	# build binary statically for linux architecture
	buildEnv="env CGO_ENABLED=0 GOOS=linux GOARCH=amd64"
fi

for binary in "${binaries[@]}"; do
	${buildEnv} go build -o ${binary} ./cmd/${binary}
	goBuildResult=$?
	if [ ${goBuildResult} != 0 ]; then
		echo -e "${RED}✗ go build ${binary} ${NC}\n$goBuildResult${NC}"
		exit 1
	else echo -e "${GREEN}√ go build ${binary} ${NC}"
	fi
done

##
# DEP STATUS
##
echo "? dep status"
depResult=$(dep status -v)
if [ $? != 0 ]; then
	echo -e "${RED}✗ dep status\n$depResult${NC}"
	exit 1
else echo -e "${GREEN}√ dep status${NC}"
fi

##
#  GO LINT
##
go build -o golint-vendored ./vendor/github.com/golang/lint/golint
buildLintResult=$?
if [ ${buildLintResult} != 0 ]; then
	echo -e "${RED}✗ go build lint${NC}\n$buildLintResult${NC}"
	exit 1
fi

golintResult=$(echo "${goFilesToCheck}" | xargs -L1 ./golint-vendored)
rm golint-vendored

if [ $(echo ${#golintResult}) != 0 ]; then
	echo -e "${RED}✗ golint\n$golintResult${NC}"
	exit 1
else echo -e "${GREEN}√ golint${NC}"
fi

##
# GO IMPORTS & FMT
##
go build -o goimports-vendored ./vendor/golang.org/x/tools/cmd/goimports
buildGoImportResult=$?
if [ ${buildGoImportResult} != 0 ]; then
	echo -e "${RED}✗ go build goimports${NC}\n$buildGoImportResult${NC}"
	exit 1
fi

goImportsResult=$(echo "${goFilesToCheck}" | xargs -L1 ./goimports-vendored -w -l)
rm goimports-vendored

if [ $(echo ${#goImportsResult}) != 0 ]; then
	echo -e "${RED}✗ goimports and fmt${NC}\n$goImportsResult${NC}"
	exit 1
else echo -e "${GREEN}√ goimports and fmt${NC}"
fi

##
# GO VET
##
packagesToVet=("./cmd/..." "./pkg/...")

for vPackage in "${packagesToVet[@]}"; do
	vetResult=$(go vet ${vPackage})
	if [ $(echo ${#vetResult}) != 0 ]; then
		echo -e "${RED}✗ go vet ${vPackage} ${NC}\n$vetResult${NC}"
		exit 1
	else echo -e "${GREEN}√ go vet ${vPackage} ${NC}"
	fi
done