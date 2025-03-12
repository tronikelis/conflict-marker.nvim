FROM nickblah/luajit:2-luarocks

RUN apt-get update && apt-get install -y build-essential

RUN luarocks install busted
RUN echo "$(luarocks path --bin)" >> ~/.profile

# install neovim
RUN <<EOF
curl -LO https://github.com/neovim/neovim/releases/download/v0.10.4/nvim-linux-x86_64.tar.gz
rm -rf /opt/nvim
tar -C /opt -xzf nvim-linux-x86_64.tar.gz
EOF

ENV PATH="$PATH:/opt/nvim-linux-x86_64/bin"

CMD ["/bin/bash", "-c", "cd ~/test && busted ."]
