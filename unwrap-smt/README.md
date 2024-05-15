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

How to run:

```shell
# Start the application
export DEBEZIUM_VERSION=2.1
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml up --detach --build
```

Grant access to mysqluser:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO '"'"'mysqluser'"'"'@'"'"'%'"'"' WITH GRANT OPTION"'
```

Create database inventory:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE inventory"'
```

View list of databases in mysql:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES"'
```

Create table customers:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD inventory -e "CREATE TABLE customers (id int NOT NULL AUTO_INCREMENT, first_name varchar(255) NOT NULL, last_name varchar(255) NOT NULL, email varchar(255) NOT NULL, PRIMARY KEY (id), UNIQUE KEY email (email)) ENGINE=InnoDB AUTO_INCREMENT=1001 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci"'
```

View list of tables in mysql:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD inventory -e "SHOW TABLES"'
```

Insert data into inventory.customers:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER  -p$MYSQL_PASSWORD inventory -e "insert into customers values(default, '"'"'Sally'"'"', '"'"'Thomas'"'"', '"'"'sally.thomas@acme.com'"'"')"'
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER  -p$MYSQL_PASSWORD inventory -e "insert into customers values(default, '"'"'George'"'"', '"'"'Bailey'"'"', '"'"'gbailey@foobar.com'"'"')"'
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER  -p$MYSQL_PASSWORD inventory -e "insert into customers values(default, '"'"'Edward'"'"', '"'"'Walker'"'"', '"'"'ed@walker.com'"'"')"'
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER  -p$MYSQL_PASSWORD inventory -e "insert into customers values(default, '"'"'Anne'"'"', '"'"'Kretchmar'"'"', '"'"'annek@noanswer.org'"'"')"'
```

View data in table inventory.customers:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD inventory -e "SELECT * FROM customers"'
```

Connect database to kafka:

```shell
# Start MySQL connector
curl --include -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ --data @unwrap-smt/source.json

# Start PostgreSQL connector
curl --include -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ --data @unwrap-smt/jdbc-sink.json
```

View list of kafka connect:

```shell
curl --silent "http://localhost:8083/connectors?expand=info&expand=status" | jq '.'
```

View list of kafka topics:

```shell
docker exec --interactive --tty unwrap-smt-kafka-1 /bin/bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --list --bootstrap-server=kafka:9092"
```

View message in kafka topic:

```shell
docker exec --interactive --tty unwrap-smt-kafka-1 /bin/bash -c "/opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server=kafka:9092 --property print.key=true --from-beginning --topic customers"
```

Check contents of the MySQL database:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER  -p$MYSQL_PASSWORD inventory -e "SELECT * FROM customers"'
+------+------------+-----------+-----------------------+
| id   | first_name | last_name | email                 |
+------+------------+-----------+-----------------------+
| 1001 | Sally      | Thomas    | sally.thomas@acme.com |
| 1002 | George     | Bailey    | gbailey@foobar.com    |
| 1003 | Edward     | Walker    | ed@walker.com         |
| 1004 | Anne       | Kretchmar | annek@noanswer.org    |
+------+------------+-----------+-----------------------+
```

Verify that the PostgreSQL database has the same content:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec postgres /bin/bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB -c "SELECT * FROM customers"'
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
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD inventory -e "INSERT INTO customers VALUES(DEFAULT, '"'"'John'"'"', '"'"'Doe'"'"', '"'"'john.doe@example.com'"'"')"'
Query OK, 1 row affected (0.02 sec)
```

Verify that PostgreSQL contains the new record:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec postgres /bin/bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB -c "SELECT * FROM customers"'
 last_name |  id  | first_name |         email         
-----------+------+------------+-----------------------
...
Doe        | 1005 | John       | john.doe@example.com
(5 rows)
```

#### Record update

Update a record in MySQL:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD inventory -e "UPDATE customers SET first_name='"'"'Jane'"'"', last_name='"'"'Roe'"'"' WHERE last_name='"'"'Doe'"'"'"'
Rows matched: 1  Changed: 1  Warnings: 0
```

Verify that record in PostgreSQL is updated:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec postgres /bin/bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB -c "SELECT * FROM customers"'
 last_name |  id  | first_name |         email         
-----------+------+------------+-----------------------
...
Roe        | 1005 | Jane       | john.doe@example.com
(5 rows)
```

#### Record delete

Delete a record in MySQL:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec mysql /bin/bash -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD inventory -e "DELETE FROM customers WHERE email='"'"'john.doe@example.com'"'"'"'
Query OK, 1 row affected (0.01 sec)
```

Verify that record in PostgreSQL is deleted:

```shell
docker-compose --file unwrap-smt/docker-compose-jdbc.yaml exec postgres /bin/bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB -c "SELECT * FROM customers"'
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

curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @es-sink.json

# Start MySQL connector

curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @source.json

```

Check contents of the MySQL database:

```shell
docker compose -f docker-compose-es.yaml exec mysql bash -c 'mysql -u $MYSQL_USER  -p$MYSQL_PASSWORD inventory -e "select * from customers"'
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
docker compose -f docker-compose-es.yaml exec mysql bash -c 'mysql -u $MYSQL_USER  -p$MYSQL_PASSWORD inventory'
mysql> insert into customers values(default, 'John', 'Doe', 'john.doe@example.com');
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
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @es-sink.json

# Start MySQL connector
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @source.json

# Start PostgreSQL connector
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @jdbc-sink.json
```

Now you can execute commands as defined in the sections for JDBC and Elasticsearch sinks and you can verify that inserts and updates are present in *both* sinks.

End the application:

```shell
# Shut down the cluster
docker compose down
```
