use tonic::transport::Server;
use tracing::info;

use helloworld_lib::create_service;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    // Get database URL from environment
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL environment variable must be set");

    // Create database connection pool
    let pool = sqlx::PgPool::connect(&database_url).await?;

    // Create the gRPC service
    let greeter_service = create_service(pool);

    // Start the gRPC server
    let addr = "0.0.0.0:50001".parse()?;
    info!("Starting gRPC server on {}", addr);

    Server::builder()
        .add_service(greeter_service)
        .serve(addr)
        .await?;

    Ok(())
} 