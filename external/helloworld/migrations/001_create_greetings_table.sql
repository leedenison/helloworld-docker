-- Create greetings table
CREATE TABLE IF NOT EXISTS greetings (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL
);

-- Insert the default greeting
INSERT INTO greetings (message) VALUES ('Hello World!') ON CONFLICT DO NOTHING; 