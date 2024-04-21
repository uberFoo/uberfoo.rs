-- This table stores the text for a page. That text is expected to be markdown.
CREATE TABLE markdown
(
    id SERIAL PRIMARY KEY,
    markdown TEXT
);

-- This is the main table for a blog post.
CREATE TABLE article
(
    id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    slug VARCHAR(255),
    content INTEGER REFERENCES markdown(id),
    published_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -- This is a page. A page has a title, an may either reference an article,
-- -- or markdown text.
-- CREATE TABLE page
-- (
--     id SERIAL PRIMARY KEY,
--     uri VARCHAR(255),
--     title VARCHAR(255),
--     page_body_id INTEGER REFERENCES page_body(id)
-- );

-- -- This is a page body. It may be either an article or markdown.
-- CREATE TABLE page_body
-- (
--     id SERIAL PRIMARY KEY,
--     article_id INTEGER REFERENCES article(id),
--     markdown_id INTEGER REFERENCES markdown(id),
--     CHECK ((article_id IS NOT NULL AND markdown_id IS NULL) OR
--         (markdown_id IS NOT NULL AND article_id IS NULL) AND
--         (article_id IS NOT NULL OR markdown_id IS NOT NULL))
-- );

CREATE TABLE script
(
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    script TEXT
);

INSERT INTO script(name, script) VALUES('counter_chart', '
<script>
    let myChart = null;
    function fetchDataAndDrawChart() {
        fetch("https://${host}/counter_data")
        .then(response => response.json())
        .then(data => {
            const ctx = document.getElementById("counter_chart").getContext("2d");
            const timestamps = data.map(item => item.timestamp);
            const values = data.map(item => item.value);

            if (myChart) {
                myChart.data.labels = timestamps;
                myChart.data.datasets[0].data = values;
                myChart.update();
            } else {
                myChart = new Chart(ctx, {
                    type: "line",
                    data: {
                        labels: timestamps,
                        datasets: [{
                            label: "Counter Over Time",
                            data: values,
                            backgroundColor: "rgba(255, 99, 132, 0.2)",
                            borderColor: "rgba(132, 0, 132, 1)",
                            borderWidth: 1
                        }]
                    },
                    options: {
                        scales: {
                            x: {
                                type: "time",
                                time: {
                                    unit: "hour"
                                }
                            },
                        }
                    }
                });
            }
        })
        .catch(error => console.error("Error fetching data:", error));
    }
    fetchDataAndDrawChart();
</script>
')

CREATE TABLE script_in_page
(
    id SERIAL PRIMARY KEY,
    script_id INTEGER REFERENCES script(id),
    article_id INTEGER REFERENCES article(id)
);

-- CREATE TABLE theme
-- (
--     id SERIAL PRIMARY KEY,
--     name VARCHAR(255),
--     css TEXT
-- );

-- CREATE TABLE layout
-- (
--     id SERIAL PRIMARY KEY,
--     name VARCHAR(255),
--     head TEXT,
--     tail TEXT
-- );

-- Insert posts
WITH inserted_markdown AS (
    INSERT INTO markdown (markdown)
    VALUES ('
# Welcome to My World

Posted on April 6, 2024

## Happy Anniversary dwarf!

Today marks the one year anniversary of my programming language: [dwarf](https://github.com/uberFoo/dwarf).
I''m celebrating with a web page from the 90''s! ☺️
The seriously cool bit is that this site is served by dwarf itself, using the [hyper](https://hyper.rs) HTTP library.

I started dwarf hoping it wouldn''t take more that a few months.
And for my purposes maybe I was done in a few months, but it''s really taken a life of it''s own.
And here it is a year later.

My original plan was to create a simple DSL that I could use in the "parent" project.
That project involves models and code generation, and I''d like to write about it in the future.
All I really thought I needed was a simple, but typed, scripting language.
Using Rust as a starting place seemed like a good idea (when I started learning rust I really wanted a REPL).
As I dug into it, there were some features I thought would be useful.
The useful bits became things that would just be cool.
It was at this point I think that I became a language junkie.

There are a ton of language features that I didn''t expect to implement.
I ended up adding generics because I couldn''t live without `Option<T>` and `Result<T, E>`.
I think I added enums before generics, and I didn''t think I''d need them at first.

Loadable modules (shared libraries) were a must, and I''m glad I added them, despite the time it took to make it work.
Besides the VM (which was not planned) and the compiler (again, not planned), async took the most time.
In fact it was such a pain, and the result so neat, I split it off into the crate [puteketeke](https://docs.rs/puteketeke/latest/puteketeke/).

My toy language is actually now generally useful.
Not to say that it should be used -- there are a ton of corner cases (which is just a euphemism for unusual, consistent bugs).
However it''s most definitely useful for me, and as I use it more, the more bugs that will get fixed.

## Moving Forward

My plan currently is to build a real blogging platform with dwarf, with this page as a start.
It feels like a fun way to continue to build and develop the language, while building something real.
I hope to also come out of this with an abstraction for building sites: a framework perhaps?

To that end I plan on posting regular updates and insights into the language, the platform, and random thoughts and ideas.
To whet your whistle, there is a counter below.
The dwarf source code for the counter (the entire server, sans this content, in fact) is just below.
(If you are interested, feel free to peruse the [source code](https://github.com/uberFoo/uberfoo.rs)).

<form class="pure-form" id="myForm" action="" method="post">
    <fieldset>
        <div class="pure-g">
            <div class="pure-u-3-24">
            <button class="pure-button button-error button-small" type="button" id="decrement_button" name="foo" value="decrement">-</button>
            </div>
            <div class="pure-u-2-24">
            <label id="counter">${counter}</label>
            </div>
            <div class="pure-u-2-24">
            <button class="pure-button button-success button-small" type="button" id="increment_button" name="foo" value="increment">+</button>
            </div>
        </div>
    </fieldset>
</form>

## Technical Gibberish

```rust
use http::server::HttpServer;
use http::server::Method;
use http::server::Request;

mod slash;

async fn main() -> Future<()> {
    let server = HttpServer::new();
    let counter = 0;

    server.route("/", Method::Get, |req: Request| -> string {
        slash::Slash::emit(counter)
    });

    server.route("/counter", Method::Get, |req: Request| -> string {
        "＄{counter}"
    });

    server.route("/increment", Method::Post, |req: Request| -> string {
        counter = counter + 1;
        "＄{counter}"
    });

    server.route("/decrement", Method::Post, |req: Request| -> string {
        counter = counter - 1;
        "＄{counter}"
    });

    server.route("/help", Method::Get, |req: Request| -> string {
        "
        <p>hit the /counter endpoint to view the counter</p>
        <p>post to /increment to increment the counter</p>
        <p>post to /decrement to decrement the counter</p>
        "
    });

    server.serve(80).await
}
```

Notice that the counter variable is not only shared between the routes, but it''s also shared with the `server.serve()` method.
That means that this counter is not unique to any single session.
Or, turned on it''s head, the counter is shared between all sessions.

Another interesting thing to point out is that the routes pass closures to the server.
This is necessary so that we can return the right stuff when an endpoint is hit.
Getting this done was no small feat.

To call the closure from the dynamic library involves saving the closed over function and environment in the main memory space.
The saved function is then invoked across the FFI boundary from the dynamic library.
And of course the result must be returned from the main binary to the shared library.
Ultimately it''s a pretty simple solution, and getting there was tricky.
I''ll write a post about it soon.

I hope that you found this post gratifying.
If you do plan on coming back -- this space is under construction, and it''s gonna be awesome.
And don''t forget to visit the dwarf repository and leave a star!
Please, and thank you!

  -- Keith Star
  ')
    RETURNING id
)
INSERT INTO article (title, slug, content, published_at)
SELECT 'Take a Number Please', 'counter', id, TIMESTAMP '2024-04-06 00:04:20'
FROM inserted_markdown;

WITH inserted_markdown AS (
    INSERT INTO markdown (markdown)
    VALUES ('
# Welcome to My World

Posted on April 16, 2024

## Ready for a database?

[Last time](http://uberfoo.rs/blog/counter) I introduced dwarf, and showed off a counter.
I also stated my intention to use a blog as a motivation.

To really get a blog off the ground we really need a place to store our posts.
Currently these are just files in the file system, and that''s not going to cut it for long.
To that end I created a simple database plugin for dwarf.
Next time I''ll discuss the plugin architecture, and how exactly we get this to work in Rust.

For now enjoy a persistent counter, with a chart to boot!
The chart shows the last 100 updates to the counter.
The y-axis is the counter value, and the x-axis is the time of the update and the scale is seconds.


<form class="pure-form" id="myForm" action="" method="post">
    <fieldset>
        <div class="pure-g">
            <div class="pure-u-3-24">
            <button class="pure-button button-error button-small" type="button" id="decrement_button" name="foo" value="decrement">-</button>
            </div>
            <div class="pure-u-2-24">
            <label id="counter">${counter}</label>
            </div>
            <div class="pure-u-2-24">
            <button class="pure-button button-success button-small" type="button" id="increment_button" name="foo" value="increment">+</button>
            </div>
        </div>
    </fieldset>
</form>

<canvas id="counter_chart" width="400" height="400"></canvas>
')
    RETURNING id
)
INSERT INTO article (title, slug, content, published_at)
SELECT 'Persistence!', 'database', id, TIMESTAMP '2024-04-16 00:04:20'
FROM inserted_markdown;