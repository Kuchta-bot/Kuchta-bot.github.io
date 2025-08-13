#!/bin/bash
# Connecting to a foreign Merge request
mr(){
  MR=$1 \
&& MRWHO="review" \
&& LOCAL_BRANCH="${MRWHO}/${MR}" \
&& git branch -D $LOCAL_BRANCH 2>/dev/null || true \
&& git fetch origin merge-requests/${MR}/head:${LOCAL_BRANCH} \
&& git checkout $LOCAL_BRANCH
}