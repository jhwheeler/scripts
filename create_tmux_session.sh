#!/bin/bash

SESSION_NAME="work_session"
WINDOW_NAME_1="vim"
WINDOW_NAME_2="server"
WINDOW_NAME_3="shell"

if tmux has-session -t $SESSION_NAME 2>/dev/null; then
  echo "Session $SESSION_NAME already exists; attaching to it."
  tmux attach-session -t $SESSION_NAME
else
  tmux new-session -d -s $SESSION_NAME
  tmux new-window -d -n $WINDOW_NAME_1
  tmux new-window -d -n $WINDOW_NAME_2
  tmux new-window -d -n $WINDOW_NAME_3

  tmux switch -t $SESSION_NAME
fi
