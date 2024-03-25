eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Postgres 16
if [ -d "/home/linuxbrew/.linuxbrew/opt/postgresql@16/bin" ]; then
  export PATH="/home/linuxbrew/.linuxbrew/opt/postgresql@16/bin:$PATH"
fi
