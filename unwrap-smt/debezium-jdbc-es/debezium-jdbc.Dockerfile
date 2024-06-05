ARG DEBEZIUM_VERSION
FROM quay.io/debezium/connect:${DEBEZIUM_VERSION}
ENV KAFKA_CONNECT_JDBC_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-jdbc
ENV KAFKA_CONNECT_AVRO_CONVERTER_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-avro-converter

ARG POSTGRES_VERSION=42.5.1
ARG KAFKA_JDBC_VERSION=5.3.2
ARG KAFKA_AVRO_CONVERTER_VERSION=7.6.1

# Deploy PostgreSQL JDBC Driver
RUN cd /kafka/libs && curl -sO https://jdbc.postgresql.org/download/postgresql-$POSTGRES_VERSION.jar

# Deploy Kafka Connect JDBC
RUN mkdir $KAFKA_CONNECT_JDBC_DIR && cd $KAFKA_CONNECT_JDBC_DIR &&\
	curl -sO https://packages.confluent.io/maven/io/confluent/kafka-connect-jdbc/$KAFKA_JDBC_VERSION/kafka-connect-jdbc-$KAFKA_JDBC_VERSION.jar

# Deploy Kafka Connect AVRO Converter
RUN mkdir $KAFKA_CONNECT_AVRO_CONVERTER_DIR && cd $KAFKA_CONNECT_AVRO_CONVERTER_DIR &&\
	curl -sO https://packages.confluent.io/maven/io/confluent/kafka-connect-avro-converter/$KAFKA_AVRO_CONVERTER_VERSION/kafka-connect-avro-converter-$KAFKA_AVRO_CONVERTER_VERSION.jar
