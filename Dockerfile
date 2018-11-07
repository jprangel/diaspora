FROM jpolarix/diaspora-stack-devops-build 

USER root

RUN apt-get update \
	&& apt-get -y install gosu libidn11-dev

USER diaspora

COPY ./ /diaspora/

RUN ls -la /diaspora/
RUN script/configure_bundler

USER root

RUN cp -arf docker/aws_ecs/docker-entrypoint.sh /entrypoint.sh \
    &&  cp -arf docker/aws_ecs/docker-exec-entrypoint.sh /exec-entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["./script/server"]



