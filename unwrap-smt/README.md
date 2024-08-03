# Debezium Unwrap SMT Demo

This setup is going to demonstrate how to receive events from MySQL database and stream them down to a PostgreSQL database and/or an Elasticsearch server using the [Debezium Event Flattening SMT](https://debezium.io/docs/configuration/event-flattening/).

## Table of Contents

* [JDBC Sink](#jdbc-sink)
  * [Topology](#topology)
  * [Usage](#usage)
    * [New record](#new-record)
    * [Record update](#record-update)
    * [Record delete](#record-delete)
* [Elasticsearch Sink](#elasticsearch-sink)
  * [Topology](#topology-1)
  * [Usage](#usage-1)
    * [New record](#new-record-1)
    * [Record update](#record-update-1)
    * [Record delete](#record-delete-1)
* [Two Parallel Sinks](#two-parallel-sinks)
  * [Topology](#topology-2)
  * [Usage](#usage-2)

## JDBC Sink

### Topology

```
                   +-------------+
                   |             |
                   |    MySQL    |
                   |             |
                   +------+------+
                          |
                          |
                          |
          +---------------v------------------+
          |                                  |
          |           Kafka Connect          |
          |  (Debezium, JDBC connectors)     |
          |                                  |
          +---------------+------------------+
                          |
                          |
                          |
                          |
                  +-------v--------+
                  |                |
                  |   PostgreSQL   |
                  |                |
                  +----------------+


```
We are using Docker Compose to deploy following components
* MySQL
* Kafka
  * ZooKeeper
  * Kafka Broker
  * Kafka Connect with [Debezium](https://debezium.io/) and  [JDBC](https://github.com/confluentinc/kafka-connect-jdbc) Connectors
* PostgreSQL

### Usage

How to build connect image:

```shell
cd unwrap-smt/debezium-jdbc-es
docker build --no-cache --file debezium-jdbc.Dockerfile . --tag ibnummuhammad/debezium-connect-jdbc:2.8.14
```

How to run:

```shell
# Start the application
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml up --detach --build
```

Grant access to mysqluser:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user root --password=$MYSQL_ROOT_PASSWORD --execute "GRANT ALL PRIVILEGES ON *.* TO '"'"'mysqluser'"'"'@'"'"'%'"'"' WITH GRANT OPTION"'
```

Create database inventory:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER --password=$MYSQL_PASSWORD --execute "CREATE DATABASE inventory"'
```

View list of databases in mysql:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER --password=$MYSQL_PASSWORD --execute "SHOW DATABASES"'
```

Create table customers:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER --password=$MYSQL_PASSWORD inventory --execute "CREATE TABLE customers (first_name varchar(255), last_name varchar(255), email varchar(255)) ENGINE=InnoDB"'
```

View list of tables in mysql:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER --password=$MYSQL_PASSWORD inventory --execute "SHOW TABLES"'
```

Insert data into inventory.customers:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER  --password=$MYSQL_PASSWORD inventory --execute "INSERT INTO customers VALUES('"'"'Sally'"'"', '"'"'Thomas'"'"', '"'"'sally.thomas@acme.com'"'"')"'
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER  --password=$MYSQL_PASSWORD inventory --execute "INSERT INTO customers VALUES('"'"'George'"'"', '"'"'Bailey'"'"', '"'"'gbailey@foobar.com'"'"')"'
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER  --password=$MYSQL_PASSWORD inventory --execute "INSERT INTO customers VALUES('"'"'Edward'"'"', '"'"'Walker'"'"', '"'"'ed@walker.com'"'"')"'
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER  --password=$MYSQL_PASSWORD inventory --execute "INSERT INTO customers VALUES('"'"'Anne'"'"', '"'"'Kretchmar'"'"', '"'"'annek@noanswer.org'"'"')"'
```

View data in table inventory.customers:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER --password=$MYSQL_PASSWORD inventory --execute "SELECT * FROM customers"'
```

Create table schema:

```shell
docker exec --interactive --tty unwrap-smt-postgres-1 /bin/bash -c 'psql --username $POSTGRES_USER $POSTGRES_DB --command "CREATE SCHEMA development_ibnu_muhammad"'
```

Connect database to kafka:

```shell
# Start PostgreSQL Source Connector
curl --include -X POST -H 'Accept:application/json' -H 'Content-Type:application/json' http://localhost:8083/connectors/ --data @unwrap-smt/debezium-source-postgres.json

# Start MySQL connector
curl --include -X POST -H 'Accept:application/json' -H 'Content-Type:application/json' http://localhost:8083/connectors/ --data @unwrap-smt/source.json

# Start PostgreSQL connector
curl --include -X POST -H 'Accept:application/json' -H 'Content-Type:application/json' http://localhost:8083/connectors/ --data @unwrap-smt/jdbc-sink-redshift.json
```

View list of kafka connect:

```shell
curl --silent 'http://localhost:8083/connectors?expand=info&expand=status' | jq '.'
curl --silent 'http://localhost:8083/connector-plugins' | jq '.[].class'
```

View list of kafka topics:

```shell
docker exec --interactive --tty unwrap-smt-kafka-1 /bin/bash -c '/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list'
```

View message in kafka topic:

```shell
docker exec --interactive --tty unwrap-smt-kafka-1 /bin/bash -c '/opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --property print.key=true --from-beginning --topic customers'
```

```shell
docker exec --interactive --tty unwrap-smt-kafka-1 /bin/bash -c '/opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --property print.key=true --from-beginning --topic topic-kafka-redshift'
```

Check contents of the MySQL database:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER  --password=$MYSQL_PASSWORD inventory --execute "SELECT * FROM customers"'
+------+------------+-----------+-----------------------+
| id   | first_name | last_name | email                 |
+------+------------+-----------+-----------------------+
| 1001 | Sally      | Thomas    | sally.thomas@acme.com |
| 1002 | George     | Bailey    | gbailey@foobar.com    |
| 1003 | Edward     | Walker    | ed@walker.com         |
| 1004 | Anne       | Kretchmar | annek@noanswer.org    |
+------+------------+-----------+-----------------------+
```

#### Insert directly in Kafka Producer

Open kafka-console-producer without key:
```shell
docker exec --interactive --tty unwrap-smt-kafka-1 /bin/bash -c 'export JMX_PORT=0 && /opt/bitnami/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:9092 --topic topic-kafka-redshift'
```

Insert message in kafka-console-producer without key:
```shell
{ "schema": { "type": "struct", "fields": [ { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "params" }, { "type": "string", "optional": false, "field": "payload" }, { "type": "string", "optional": false, "field": "etl_id" }, { "type": "string", "optional": false, "field": "etl_id_ts" }, { "type": "string", "optional": false, "field": "etl_id_partition" }, { "type": "string", "optional": false, "field": "run_ts" } ], "optional": true, "name": "dbserver1.inventory.customers.Value", "field": "before" }, { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "params" }, { "type": "string", "optional": false, "field": "payload" }, { "type": "string", "optional": false, "field": "etl_id" }, { "type": "string", "optional": false, "field": "etl_id_ts" }, { "type": "string", "optional": false, "field": "etl_id_partition" }, { "type": "string", "optional": false, "field": "run_ts" } ], "optional": true, "name": "dbserver1.inventory.customers.Value", "field": "after" }, { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "version" }, { "type": "string", "optional": false, "field": "connector" }, { "type": "string", "optional": false, "field": "name" }, { "type": "int64", "optional": false, "field": "ts_ms" }, { "type": "string", "optional": true, "name": "io.debezium.data.Enum", "version": 1, "parameters": { "allowed": "true,last,false,incremental" }, "default": "false", "field": "snapshot" }, { "type": "string", "optional": false, "field": "db" }, { "type": "string", "optional": true, "field": "sequence" }, { "type": "string", "optional": true, "field": "table" }, { "type": "int64", "optional": false, "field": "server_id" }, { "type": "string", "optional": true, "field": "gtid" }, { "type": "string", "optional": false, "field": "file" }, { "type": "int64", "optional": false, "field": "pos" }, { "type": "int32", "optional": false, "field": "row" }, { "type": "int64", "optional": true, "field": "thread" }, { "type": "string", "optional": true, "field": "query" } ], "optional": false, "name": "io.debezium.connector.mysql.Source", "field": "source" }, { "type": "string", "optional": false, "field": "op" }, { "type": "int64", "optional": true, "field": "ts_ms" }, { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "id" }, { "type": "int64", "optional": false, "field": "total_order" }, { "type": "int64", "optional": false, "field": "data_collection_order" } ], "optional": true, "name": "event.block", "version": 1, "field": "transaction" } ], "optional": false, "name": "dbserver1.inventory.customers.Envelope", "version": 1 }, "payload": { "before": null, "after": { "params": "banco", "payload": "iben", "etl_id": "muhammad", "etl_id_ts": "ibnu_muhammad@gmail.com", "etl_id_partition": "partisi", "run_ts": "lari" }, "source": { "version": "2.1.4.Final", "connector": "mysql", "name": "dbserver1", "ts_ms": 1717568433000, "snapshot": "false", "db": "inventory", "sequence": null, "table": "customers", "server_id": 1, "gtid": null, "file": "binlog.000002", "pos": 2645, "row": 0, "thread": 23, "query": null }, "op": "c", "ts_ms": 1717568433831, "transaction": null } }
```
------

Open kafka-console-producer without key:
```shell
docker exec --interactive --tty unwrap-smt-kafka-1 /bin/bash -c 'export JMX_PORT=0 && /opt/bitnami/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:9092 --topic topic-kafka-redshift'
```

Insert message in kafka-console-producer without key and json data:
```shell
{ "schema": { "type": "struct", "fields": [ { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "params" }, { "type": "string", "optional": false, "field": "payload" }, { "type": "string", "optional": false, "field": "etl_id" }, { "type": "string", "optional": false, "field": "etl_id_ts" }, { "type": "int64", "optional": false, "field": "etl_id_partition" }, { "type": "string", "optional": false, "field": "run_ts" } ], "optional": true, "name": "dbserver1.inventory.customers.Value", "field": "before" }, { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "params" }, { "type": "string", "optional": false, "field": "payload" }, { "type": "string", "optional": false, "field": "etl_id" }, { "type": "string", "optional": false, "field": "etl_id_ts" }, { "type": "int64", "optional": false, "field": "etl_id_partition" }, { "type": "string", "optional": false, "field": "run_ts" } ], "optional": true, "name": "dbserver1.inventory.customers.Value", "field": "after" }, { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "version" }, { "type": "string", "optional": false, "field": "connector" }, { "type": "string", "optional": false, "field": "name" }, { "type": "int64", "optional": false, "field": "ts_ms" }, { "type": "string", "optional": true, "name": "io.debezium.data.Enum", "version": 1, "parameters": { "allowed": "true,last,false,incremental" }, "default": "false", "field": "snapshot" }, { "type": "string", "optional": false, "field": "db" }, { "type": "string", "optional": true, "field": "sequence" }, { "type": "string", "optional": true, "field": "table" }, { "type": "int64", "optional": false, "field": "server_id" }, { "type": "string", "optional": true, "field": "gtid" }, { "type": "string", "optional": false, "field": "file" }, { "type": "int64", "optional": false, "field": "pos" }, { "type": "int32", "optional": false, "field": "row" }, { "type": "int64", "optional": true, "field": "thread" }, { "type": "string", "optional": true, "field": "query" } ], "optional": false, "name": "io.debezium.connector.mysql.Source", "field": "source" }, { "type": "string", "optional": false, "field": "op" }, { "type": "int64", "optional": true, "field": "ts_ms" }, { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "id" }, { "type": "int64", "optional": false, "field": "total_order" }, { "type": "int64", "optional": false, "field": "data_collection_order" } ], "optional": true, "name": "event.block", "version": 1, "field": "transaction" } ], "optional": false, "name": "dbserver1.inventory.customers.Envelope", "version": 1 }, "payload": { "before": null, "after": { "params": "{\"id\": 1008,\"first_name\": \"bapercobaan\",\"last_name\": \"bapertama\",\"email\": \"batesting@email\"}", "payload": "{\"id\": 1008,\"first_name\": \"bapercobaan\",\"last_name\": \"bapertama\",\"email\": \"batesting@email\"}", "etl_id": "2022-10-10-11", "etl_id_ts": "2022-10-10 11:30:30", "etl_id_partition": 1698224979, "run_ts": "2022-10-10 11:30:30" }, "source": { "version": "2.1.4.Final", "connector": "mysql", "name": "dbserver1", "ts_ms": 1717568433000, "snapshot": "false", "db": "inventory", "sequence": null, "table": "customers", "server_id": 1, "gtid": null, "file": "binlog.000002", "pos": 2645, "row": 0, "thread": 23, "query": null }, "op": "c", "ts_ms": 1717568433831, "transaction": null } }
```

-------

Open kafka-console-producer:
```shell
docker exec --interactive --tty unwrap-smt-kafka-1 /bin/bash -c "export JMX_PORT=0 && /opt/bitnami/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:9092 --property 'parse.key=true' --property 'key.separator=|' --topic keluaran"
```

Insert message in kafka-console-producer:

```shell
{ "schema": { "type": "struct", "fields": [{ "type": "int32", "optional": false, "field": "id" }], "optional": false, "name": "dbserver1.inventory.customers.Key" }, "payload": { "id": 1006 } }|{ "schema": { "type": "struct", "fields": [ { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "params" }, { "type": "string", "optional": false, "field": "payload" }, { "type": "string", "optional": false, "field": "etl_id" }, { "type": "string", "optional": false, "field": "etl_id_ts" }, { "type": "string", "optional": false, "field": "etl_id_partition" }, { "type": "string", "optional": false, "field": "run_ts" } ], "optional": true, "name": "dbserver1.inventory.customers.Value", "field": "before" }, { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "params" }, { "type": "string", "optional": false, "field": "payload" }, { "type": "string", "optional": false, "field": "etl_id" }, { "type": "string", "optional": false, "field": "etl_id_ts" }, { "type": "string", "optional": false, "field": "etl_id_partition" }, { "type": "string", "optional": false, "field": "run_ts" } ], "optional": true, "name": "dbserver1.inventory.customers.Value", "field": "after" }, { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "version" }, { "type": "string", "optional": false, "field": "connector" }, { "type": "string", "optional": false, "field": "name" }, { "type": "int64", "optional": false, "field": "ts_ms" }, { "type": "string", "optional": true, "name": "io.debezium.data.Enum", "version": 1, "parameters": { "allowed": "true,last,false,incremental" }, "default": "false", "field": "snapshot" }, { "type": "string", "optional": false, "field": "db" }, { "type": "string", "optional": true, "field": "sequence" }, { "type": "string", "optional": true, "field": "table" }, { "type": "int64", "optional": false, "field": "server_id" }, { "type": "string", "optional": true, "field": "gtid" }, { "type": "string", "optional": false, "field": "file" }, { "type": "int64", "optional": false, "field": "pos" }, { "type": "int32", "optional": false, "field": "row" }, { "type": "int64", "optional": true, "field": "thread" }, { "type": "string", "optional": true, "field": "query" } ], "optional": false, "name": "io.debezium.connector.mysql.Source", "field": "source" }, { "type": "string", "optional": false, "field": "op" }, { "type": "int64", "optional": true, "field": "ts_ms" }, { "type": "struct", "fields": [ { "type": "string", "optional": false, "field": "id" }, { "type": "int64", "optional": false, "field": "total_order" }, { "type": "int64", "optional": false, "field": "data_collection_order" } ], "optional": true, "name": "event.block", "version": 1, "field": "transaction" } ], "optional": false, "name": "dbserver1.inventory.customers.Envelope", "version": 1 }, "payload": { "before": null, "after": { "params": "banco", "payload": "iben", "etl_id": "muhammad", "etl_id_ts": "ibnu_muhammad@gmail.com", "etl_id_partition": "partisi", "run_ts": "lari" }, "source": { "version": "2.1.4.Final", "connector": "mysql", "name": "dbserver1", "ts_ms": 1717568433000, "snapshot": "false", "db": "inventory", "sequence": null, "table": "customers", "server_id": 1, "gtid": null, "file": "binlog.000002", "pos": 2645, "row": 0, "thread": 23, "query": null }, "op": "c", "ts_ms": 1717568433831, "transaction": null } }
```

Verify that the PostgreSQL database has the same content:

```shell
docker exec --interactive --tty unwrap-smt-postgres-1 /bin/bash -c 'psql --username $POSTGRES_USER $POSTGRES_DB --command "SELECT * FROM data_warehouse.development_ibnu_muhammad.ekyc_pipeline_rt"'
 last_name |  id  | first_name |         email         
-----------+------+------------+-----------------------
 Thomas    | 1001 | Sally      | sally.thomas@acme.com
 Bailey    | 1002 | George     | gbailey@foobar.com
 Walker    | 1003 | Edward     | ed@walker.com
 Kretchmar | 1004 | Anne       | annek@noanswer.org
(4 rows)
```

#### New record

Insert a new record into MySQL;
```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER --password=$MYSQL_PASSWORD inventory --execute "INSERT INTO customers VALUES(DEFAULT, '"'"'John'"'"', '"'"'Doe'"'"', '"'"'john.doe@example.com'"'"')"'
Query OK, 1 row affected (0.02 sec)
```

Verify that PostgreSQL contains the new record:

```shell
docker exec --interactive --tty unwrap-smt-postgres-1 /bin/bash -c 'psql --username $POSTGRES_USER $POSTGRES_DB --command "SELECT * FROM keluaran"'
 last_name |  id  | first_name |         email         
-----------+------+------------+-----------------------
...
Doe        | 1005 | John       | john.doe@example.com
(5 rows)
```

#### Record update

Update a record in MySQL:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER --password=$MYSQL_PASSWORD inventory --execute "UPDATE customers SET first_name='"'"'Jane'"'"', last_name='"'"'Roe'"'"' WHERE last_name='"'"'Doe'"'"'"'
Rows matched: 1  Changed: 1  Warnings: 0
```

Verify that record in PostgreSQL is updated:

```shell
docker exec --interactive --tty unwrap-smt-postgres-1 /bin/bash -c 'psql --username $POSTGRES_USER $POSTGRES_DB --command "SELECT * FROM keluaran"'
 last_name |  id  | first_name |         email         
-----------+------+------------+-----------------------
...
Roe        | 1005 | Jane       | john.doe@example.com
(5 rows)
```

#### Record delete

Delete a record in MySQL:

```shell
docker exec --interactive --tty unwrap-smt-mysql-1 /bin/bash -c 'mysql --user $MYSQL_USER --password=$MYSQL_PASSWORD inventory --execute "DELETE FROM customers WHERE email='"'"'john.doe@example.com'"'"'"'
Query OK, 1 row affected (0.01 sec)
```

Verify that record in PostgreSQL is deleted:

```shell
docker exec --interactive --tty unwrap-smt-postgres-1 /bin/bash -c 'psql --username $POSTGRES_USER $POSTGRES_DB --command "SELECT * FROM keluaran"'
 last_name |  id  | first_name |         email         
-----------+------+------------+-----------------------
...
(4 rows)
```

As you can see there is no longer a 'Jane Doe' as a customer.


End application:

```shell
# Shut down the cluster
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml down
```

## Elasticsearch Sink

### Topology

```
                   +-------------+
                   |             |
                   |    MySQL    |
                   |             |
                   +------+------+
                          |
                          |
                          |
          +---------------v------------------+
          |                                  |
          |           Kafka Connect          |
          |    (Debezium, ES connectors)     |
          |                                  |
          +---------------+------------------+
                          |
                          |
                          |
                          |
                  +-------v--------+
                  |                |
                  | Elasticsearch  |
                  |                |
                  +----------------+


```
We are using Docker Compose to deploy the following components:

* MySQL
* Kafka
  * ZooKeeper
  * Kafka Broker
  * Kafka Connect with [Debezium](https://debezium.io/) and  [Elasticsearch](https://github.com/confluentinc/kafka-connect-elasticsearch) Connectors
* Elasticsearch

### Usage

How to run:

```shell
# Start the application

export DEBEZIUM_VERSION=2.1
docker compose -f docker-compose-es.yaml up --build

# Start Elasticsearch connector

curl -i -X POST -H 'Accept:application/json' -H 'Content-Type:application/json' http://localhost:8083/connectors/ -d @es-sink.json

# Start MySQL connector

curl -i -X POST -H 'Accept:application/json' -H 'Content-Type:application/json' http://localhost:8083/connectors/ -d @source.json

```

Check contents of the MySQL database:

```shell
docker compose -f docker-compose-es.yaml exec mysql bash -c 'mysql --user $MYSQL_USER  --password=$MYSQL_PASSWORD inventory --execute "select * from customers"'
+------+------------+-----------+-----------------------+
| id   | first_name | last_name | email                 |
+------+------------+-----------+-----------------------+
| 1001 | Sally      | Thomas    | sally.thomas@acme.com |
| 1002 | George     | Bailey    | gbailey@foobar.com    |
| 1003 | Edward     | Walker    | ed@walker.com         |
| 1004 | Anne       | Kretchmar | annek@noanswer.org    |
+------+------------+-----------+-----------------------+
```

Verify that Elasticsearch has the same content:

```shell
curl 'http://localhost:9200/customers/_search?pretty'
{
  "took" : 42,
  "timed_out" : false,
  "_shards" : {
    "total" : 5,
    "successful" : 5,
    "failed" : 0
  },
  "hits" : {
    "total" : 4,
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1001",
        "_score" : 1.0,
        "_source" : {
          "id" : 1001,
          "first_name" : "Sally",
          "last_name" : "Thomas",
          "email" : "sally.thomas@acme.com"
        }
      },
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1004",
        "_score" : 1.0,
        "_source" : {
          "id" : 1004,
          "first_name" : "Anne",
          "last_name" : "Kretchmar",
          "email" : "annek@noanswer.org"
        }
      },
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1002",
        "_score" : 1.0,
        "_source" : {
          "id" : 1002,
          "first_name" : "George",
          "last_name" : "Bailey",
          "email" : "gbailey@foobar.com"
        }
      },
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1003",
        "_score" : 1.0,
        "_source" : {
          "id" : 1003,
          "first_name" : "Edward",
          "last_name" : "Walker",
          "email" : "ed@walker.com"
        }
      }
    ]
  }
}

```
#### New record

Insert a new record into MySQL:

```shell
docker compose -f docker-compose-es.yaml exec mysql bash -c 'mysql --user $MYSQL_USER  --password=$MYSQL_PASSWORD inventory'
mysql> INSERT INTO customers VALUES(default, 'John', 'Doe', 'john.doe@example.com');
Query OK, 1 row affected (0.02 sec)
```

Check that Elasticsearch contains the new record:

```shell
curl 'http://localhost:9200/customers/_search?pretty'
...
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1005",
        "_score" : 1.0,
        "_source" : {
          "id" : 1005,
          "first_name" : "John",
          "last_name" : "Doe",
          "email" : "john.doe@example.com"
        }
      }
...
```

#### Record update

Update a record in MySQL:

```shell
mysql> update customers set first_name='Jane', last_name='Roe' where last_name='Doe';
Query OK, 1 row affected (0.02 sec)
Rows matched: 1  Changed: 1  Warnings: 0
```

Verify that record in Elasticsearch is updated:

```shell
curl 'http://localhost:9200/customers/_search?pretty'
...
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1005",
        "_score" : 1.0,
        "_source" : {
          "id" : 1005,
          "first_name" : "Jane",
          "last_name" : "Roe",
          "email" : "john.doe@example.com"
        }
      }
...
```


#### Record delete

Delete a record in MySQL:

```shell
mysql> delete from customers where email='john.doe@example.com';
Query OK, 1 row affected (0.01 sec)
```

Verify that record in Elasticsearch is deleted:

```shell
curl 'http://localhost:9200/customers/_search?pretty'
{
  "took" : 42,
  "timed_out" : false,
  "_shards" : {
    "total" : 5,
    "successful" : 5,
    "failed" : 0
  },
  "hits" : {
    "total" : 4,
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1001",
        "_score" : 1.0,
        "_source" : {
          "id" : 1001,
          "first_name" : "Sally",
          "last_name" : "Thomas",
          "email" : "sally.thomas@acme.com"
        }
      },
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1004",
        "_score" : 1.0,
        "_source" : {
          "id" : 1004,
          "first_name" : "Anne",
          "last_name" : "Kretchmar",
          "email" : "annek@noanswer.org"
        }
      },
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1002",
        "_score" : 1.0,
        "_source" : {
          "id" : 1002,
          "first_name" : "George",
          "last_name" : "Bailey",
          "email" : "gbailey@foobar.com"
        }
      },
      {
        "_index" : "customers",
        "_type" : "customer",
        "_id" : "1003",
        "_score" : 1.0,
        "_source" : {
          "id" : 1003,
          "first_name" : "Edward",
          "last_name" : "Walker",
          "email" : "ed@walker.com"
        }
      }
    ]
  }
}

```

As you can see there is no longer a 'Jane Doe' as a customer.


End the application:

```shell
# Shut down the cluster
docker compose -f docker-compose-es.yaml down
```

## Two Parallel Sinks

### Topology

```
                   +-------------+
                   |             |
                   |    MySQL    |
                   |             |
                   +------+------+
                          |
                          |
                          |
          +---------------v------------------+
          |                                  |
          |           Kafka Connect          |
          |  (Debezium, JDBC, ES connectors) |
          |                                  |
          +---+-----------------------+------+
              |                       |
              |                       |
              |                       |
              |                       |
+-------------v--+                +---v---------------+
|                |                |                   |
|   PostgreSQL   |                |   ElasticSearch   |
|                |                |                   |
+----------------+                +-------------------+

```
We are using Docker Compose to deploy the following components:

* MySQL
* Kafka
  * ZooKeeper
  * Kafka Broker
  * Kafka Connect with [Debezium](https://debezium.io/), [JDBC](https://github.com/confluentinc/kafka-connect-jdbc) and  [Elasticsearch](https://github.com/confluentinc/kafka-connect-elasticsearch) Connectors
* PostgreSQL
* Elasticsearch

### Usage

How to run:

```shell
# Start the application
export DEBEZIUM_VERSION=2.1
docker compose up --build

# Start Elasticsearch connector
curl -i -X POST -H 'Accept:application/json' -H 'Content-Type:application/json' http://localhost:8083/connectors/ -d @es-sink.json

# Start MySQL connector
curl -i -X POST -H 'Accept:application/json' -H 'Content-Type:application/json' http://localhost:8083/connectors/ -d @source.json

# Start PostgreSQL connector
curl -i -X POST -H 'Accept:application/json' -H 'Content-Type:application/json' http://localhost:8083/connectors/ -d @jdbc-sink.json
```

Now you can execute commands as defined in the sections for JDBC and Elasticsearch sinks and you can verify that inserts and updates are present in *both* sinks.

End the application:

```shell
# Shut down the cluster
docker compose down
```
