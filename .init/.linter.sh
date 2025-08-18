#!/bin/bash
cd /home/kavia/workspace/code-generation/linkedin-message-search-assistant-125929-125938/linkedin_message_search_frontend
npm run build
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
   exit 1
fi

