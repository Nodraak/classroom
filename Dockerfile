#from ubuntu:trusty
FROM phusion/baseimage:0.9.18
# XX todo use ubuntu and create several docker containers

# apt-get all dep
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential git wget \
    libssl-dev libreadline-dev zlib1g-dev libpq-dev nodejs \
    postgresql redis-server memcached openjdk-7-jre

WORKDIR /root

# apt-get es
RUN wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
RUN echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y elasticsearch

# rbenv
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv
RUN cd ~/.rbenv && src/configure && make -C src

#RUN echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
ENV PATH="/root/.rbenv/bin:$PATH"

#RUN echo 'eval "$(rbenv init -)"' >> ~/.bashrc
ENV PATH="/root/.rbenv/shims:${PATH}"
ENV RBENV_SHELL=sh
RUN command rbenv rehash 2>/dev/null
RUN rbenv() { local command; command="$1"; if [ "$#" -gt 0 ]; then shift; fi; case "$command" in rehash|shell) eval "$(rbenv "sh-$command" "$@")";; *) command rbenv "$command" "$@";; esac ;}

# ruby-build
RUN git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# ruby
RUN rbenv install 2.3.0 && rbenv global 2.3.0
RUN gem install bundler && rbenv rehash

# gh classroom
RUN git clone https://github.com/education/classroom
WORKDIR /root/classroom

# configure
RUN sed -i "s/memcached: memcached/memcached: memcached -u root/" Procfile.dev
RUN sed -i "s/#unix_socket_permissions = 0777/unix_socket_permissions = 0777/" /etc/postgresql/9.3/main/postgresql.conf
RUN service postgresql start && su postgres -s /bin/bash -c "cd / && psql -c 'CREATE USER root; ALTER USER root CREATEDB'" && service postgresql stop
RUN sed -i "s/bundle exec rails server/bundle exec rails server -b 0.0.0.0/" script/server

# workaround (git://url does not work)
RUN git clone 'http://github.com/Soliah/peek-sidekiq.git' "/root/.rbenv/versions/2.3.0/lib/ruby/gems/2.3.0/cache/bundler/git/peek-sidekiq-018f734a47db553ec3325306389f49eedf6d1348" --bare --no-hardlinks --quiet
#RUN bundle install
RUN service postgresql start && script/setup && service postgresql stop

EXPOSE 3000
CMD service postgresql start && service redis-server start && service memcached start && service elasticsearch start \
    && (script/workers > sw_stdout 2> sw_stderr &) \
    && script/server
