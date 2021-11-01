resource "aws_appsync_graphql_api" "auditlog" {
  authentication_type = "API_KEY"
  name                = "auditlog-cverbinnen"
  schema = <<EOF
    schema {
      query: Query
      mutation: Mutation
    }
    type Query {
      singlePost(id: ID!): Post
      allPosts: [Post]
    }
    type Mutation {
      putPost(id: ID!, title: String!): Post
    }
    type Post {
      id: ID!
      title: String!
    }
EOF
}

resource "aws_appsync_api_key" "example" {
  api_id  = aws_appsync_graphql_api.auditlog.id
  expires = "2021-12-25T04:00:00Z"
}

resource "aws_appsync_datasource" "es" {
  api_id           = aws_appsync_graphql_api.auditlog.id
  name             = "appsync_es_source"
  service_role_arn = aws_iam_role.AppSyncESServiceRole.arn
  type             = "AMAZON_ELASTICSEARCH"
  elasticsearch_config {
    endpoint = "https://${aws_elasticsearch_domain.es.endpoint}"
  }
}

resource "aws_appsync_resolver" "putPost" {
  api_id      = aws_appsync_graphql_api.auditlog.id
  field       = "putPost"
  type        = "Mutation"
  data_source = aws_appsync_datasource.es.name

  request_template = <<EOF
{
  "version": "2017-02-28",
  "operation": "PUT",
  "path": $util.toJson("/id/post/$${context.arguments.id}"),
  "params": {
    "headers":{},
    "queryString":{},
    "body":{
      "id": $util.toJson($context.arguments.id),
      "title": $util.toJson($context.arguments.title)
    }
  }
}
EOF

response_template = <<EOF
$util.toJson($context.result.get("_source"))
EOF
}


resource "aws_appsync_resolver" "singlePost" {
  api_id      = aws_appsync_graphql_api.auditlog.id
  field       = "singlePost"
  type        = "Query"
  data_source = aws_appsync_datasource.es.name

  request_template = <<EOF
{
  "version": "2017-02-28",
  "operation": "GET",
  "path": $util.toJson("/id/post/$${context.arguments.id}"),
  "params": {}
}
EOF

response_template = <<EOF
$util.toJson($context.result.get("_source"))
EOF
}

resource "aws_appsync_resolver" "allPosts" {
  api_id      = aws_appsync_graphql_api.auditlog.id
  field       = "allPosts"
  type        = "Query"
  data_source = aws_appsync_datasource.es.name

  request_template = <<EOF
 {
  "version": "2017-02-28",
  "operation": "GET",
  "path": "/id/post/_search",
  "params": {
    "body": {
        "from": "0",
        "size": "50"
    }
  }
}
EOF

response_template = <<EOF
[
  #foreach($entry in $context.result.hits.hits)
      #if( $velocityCount > 1 ) , #end
        $util.toJson($entry.get("_source"))
  #end
]
EOF
}