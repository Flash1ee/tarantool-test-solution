FROM ubuntu

ENV TZ=Europe/Moscow

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt update
RUN apt-get install -y curl
RUN curl -L https://tarantool.io/vOXZJz/release/2.6/installer.sh | bash
RUN apt-get -y install tarantool


RUN apt-get install cartridge-cli
ENV PORT=8081
EXPOSE ${PORT}

COPY . /opt/tarantool/books-storage
WORKDIR /opt/tarantool/books-storage

RUN cartridge build
CMD ["cartridge", "start"]
