use tonic::{Request, Response, Status};
use sqlx::PgPool;

pub mod helloworld {
    tonic::include_proto!("helloworld");
}

use helloworld::greeter_server::{Greeter, GreeterServer};
use helloworld::{HelloReply, HelloRequest};

pub struct GreeterService {
    pool: PgPool,
}

impl GreeterService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[tonic::async_trait]
impl Greeter for GreeterService {
    async fn say_hello(
        &self,
        _request: Request<HelloRequest>,
    ) -> Result<Response<HelloReply>, Status> {
        // Query the database for the greeting message
        let greeting = sqlx::query_as::<_, GreetingRow>(
            "SELECT message FROM greetings LIMIT 1"
        )
        .fetch_one(&self.pool)
        .await
        .map_err(|e| {
            tracing::error!("Database error: {}", e);
            Status::internal("Database error")
        })?;

        Ok(Response::new(HelloReply {
            message: greeting.message,
        }))
    }
}

#[derive(sqlx::FromRow)]
struct GreetingRow {
    message: String,
}

pub fn create_service(pool: PgPool) -> GreeterServer<GreeterService> {
    GreeterServer::new(GreeterService::new(pool))
} 