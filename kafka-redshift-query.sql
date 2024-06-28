INSERT INTO
  \"data_warehouse\".\"development_ibnu_muhammad\".\"testing_ibn_kubeflow1\" (
    \"params\",
    \"payload\",
    \"etl_id\",
    \"etl_id_ts\",
    \"etl_id_partition\",
    \"run_ts\"
  )
VALUES
  (
    (
      JSON_PARSE (
        '{ \"type\": \"string\", \"optional\": false, \"field\": \"params\" }'
      )
    ),
    (
      JSON_PARSE (
        '{ \"type\": \"string\", \"optional\": false, \"field\": \"params\" }'
      )
    ),
    ('2019-10-10-11'),
    ('2022-10-10 11:30:30+00'),
    ('1698224979'::int8),
    ('2022-10-10 11:30:30+00')
  )