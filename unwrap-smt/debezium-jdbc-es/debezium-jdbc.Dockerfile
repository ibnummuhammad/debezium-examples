FROM ibnummuhammad/debezium-connect:2.6

# Deploy PostgreSQL JDBC Driver
COPY postgresql-42.7.3.jar /kafka/libs/postgresql-42.7.3.jar

# Deploy Redshift JDBC Driver
COPY redshift-jdbc42-2.1.0.28.jar /kafka/libs/redshift-jdbc42-2.1.0.28.jar

# Deploy Kafka Connect JDBC
ENV KAFKA_CONNECT_JDBC_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-jdbc
RUN mkdir $KAFKA_CONNECT_JDBC_DIR
COPY kafka-connect-jdbc-10.7.6.jar $KAFKA_CONNECT_JDBC_DIR

# Deploy Debezium Postgres Connector
ENV DEBEZIUM_CONNECTOR_POSTGRES_DIR=$KAFKA_CONNECT_PLUGINS_DIR/debezium-connector-postgres
RUN mkdir $DEBEZIUM_CONNECTOR_POSTGRES_DIR
COPY debezium-core-2.6.2.Final.jar $DEBEZIUM_CONNECTOR_POSTGRES_DIR
COPY debezium-api-2.6.2.Final.jar $DEBEZIUM_CONNECTOR_POSTGRES_DIR
COPY debezium-connector-postgres-2.6.2.Final.jar $DEBEZIUM_CONNECTOR_POSTGRES_DIR
