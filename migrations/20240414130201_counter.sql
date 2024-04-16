-- Add migration script here
CREATE TABLE counter
(
    sequence_number SERIAL PRIMARY KEY,
    counter INTEGER,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial row
INSERT INTO counter (counter) VALUES (0);