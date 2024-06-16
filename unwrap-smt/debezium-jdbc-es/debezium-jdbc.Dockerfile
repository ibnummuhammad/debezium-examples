FROM ibnummuhammad/debezium-connect:2.6
ENV KAFKA_CONNECT_JDBC_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-jdbc

ARG POSTGRES_VERSION=42.5.1
ARG KAFKA_JDBC_VERSION=10.7.4

# Deploy PostgreSQL JDBC Driver
RUN cd /kafka/libs && curl -sO https://jdbc.postgresql.org/download/postgresql-$POSTGRES_VERSION.jar

# Deploy Redshift JDBC Driver
COPY redshift-jdbc42-2.1.0.28.jar /kafka/libs/redshift-jdbc42-2.1.0.28.jar

# Deploy Kafka Connect JDBC
RUN mkdir $KAFKA_CONNECT_JDBC_DIR
COPY kafka-connect-jdbc-10.7.6.jar $KAFKA_CONNECT_JDBC_DIR
