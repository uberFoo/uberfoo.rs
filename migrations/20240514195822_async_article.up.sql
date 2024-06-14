-- This table stores the tags
CREATE TABLE tags
(
    id SERIAL PRIMARY KEY,
    tag VARCHAR(255) UNIQUE
);

-- This table creates a many-to-many relationship between articles and tags
CREATE TABLE article_tags
(
    article_slug VARCHAR(255) REFERENCES article(slug) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tags(id),
    PRIMARY KEY (article_slug, tag_id)
);

ALTER TABLE article
ADD COLUMN is_draft BOOLEAN DEFAULT TRUE;

UPDATE article
SET is_draft = FALSE
where slug = 'plugins';

INSERT INTO tags (tag)
VALUES ('dwarf'), ('rust'), ('blog');

WITH markdown_insert AS (
    INSERT INTO markdown (markdown)
    VALUES('
In this article I''m going to describe one way to add async to a virtual machine in Rust.
Adding async to a VM is actually pretty simple using the [Pūteketeke](https://www.github.com/uberFoo/puteketeke) crate.
To be specific, I''m assuming that the VM already exists, and that we want to add async support to it.
For brevity''s sake, I''m not going to talk about parsers, bytecode, or anything like that.
I assume that the reader, having already implemented their VM is familiar with these concepts.

## Async in a Virtual Machine

What exactly does it mean to have an async virtual machine?
In the context of this article, it means that the VM can execute tasks concurrently.
This is a powerful feature, as it allows the VM to perform multiple tasks at the same time.
This can be useful for a variety of applications, such as web servers, game engines, and more.
Basically any place that something can happen out of the blue, or where you want to do multiple things at once.

## Preliminaries

Before we get started, let''s define some terms.
- **Task**: A task is a unit of work that the VM can execute.
- **Executor**: An executor is responsible for running tasks on the VM.

Note that the code examples are written in [dwarf](https://www.github.com/uberFoo/dwarf).
Be a gem and leave a star on the repo!

Below we await a task, as an async block, in the current thread; it will print "Hello, world!" to the console:

```rust
let task = async {
    print("Hello, world!");
};

task.await;
```

The `task` is not executed until the `await` statement is reached.

There must also be a way to spawn tasks that begin execution independent of the current thread.
Below we spawn a task as an async lambda, which will also print "Hello, world!" to the console:

```rust
let task = chacha::spawn(async || -> {
    print("Hello, world!");
});

task.await;
```

`chacha::spawn` is a dwarf built-in function that spawns a task.

The primary difference is that a spawned task will begin running immediately, while an awaited task will run in the current thread, and only runs when the task is awaited.


It is  assumed that your VM has a `Value` type that represents the values that the VM operates upon: e.g., integers, strings, etc.
This is so that we can add a Task type.

## Task Type

When a an async block or lambda is spawned, it creates a task.
A task is a unit of work that the VM can execute.
We need a task because we need to be able to pass them around, and to be able to await them.

The task type is defined as follows:

```rust
pub enum Value {
    ...
    Task {
        name: String,
        running: bool,
        task: RefType<Option<AsyncTask<''static, ValueResult>>>,
    },
    ...
}

pub type RefType<T> = Rc<RefCell<T>>;
pub type ValueResult = Result<RefType<Value>, Error>;
```

The `Task` variant contains the name of the task, a boolean indicating whether the task is running, and the task itself.
The task is a reference to an `AsyncTask` type, which is a type provided by the `Pūteketeke` crate.
`AsyncTask` wraps a [smol](https://github.com/smol-rs/smol) task, which wraps a [`Future`](https://rust-lang.github.io/async-book/02_execution/02_future.html).

The `RefType` wrapping the task is a reference counted type, which allows us to share the task across threads.
In this specific case it''s an `Arc<RwLock<T>>`.
The `ValueResult` type is a type that represents the result of the task.
The definition of `ValueResult` is ` Result<RefType<Value>, Error>`.

## The Pūteketeke Crate
Now is a good time to vector off and talk about the `Pūteketeke` crate.
Pūteketeke is a crate that provides a straightforward means of adding async to a VM.
`AsyncTask` was described above, which is a type provided by the crate.
We''ll dive more deeply into that as well as a few other key types.

### AsyncTask in depth

An `AsyncTask` encapsulates everything needed to run on the `Executor`.
The definition follows:

```rust
pub struct AsyncTask<''a, T> {
    inner: Option<SmolTask<T>>,
    worker: AsyncWorker<''a>,
    started: AtomicBool,
    waker: Option<Waker>,
    id: usize,
}
```


`AsyncTask` is generic over `''a` and `T`, where `T` is the your `Task` type.
For dwarf is this the `Task` variant of the `Value` type.

`AsyncTask` type contains an inner `SmolTask`, an `AsyncWorker`, an `AtomicBool`, a `Waker`, and an `id`.
The `SmolTask` an alias for the `Task` type provided by the `smol` crate.
The `AsyncWorker` is a lightweight type that wraps the `Executor` type in a smart pointer.
This allows us to clone the `Executor` and share it across threads.
The `AtomicBool` is used to track whether the task has started.
The `Waker` is used to wake the task when it is ready to run.

An `AsyncTask` is created using the `new` function.
We want to be able to create an `AsyncTask` from a `Future`.
The `new` function takes an `AsyncWorker` and a `Future` and returns an `AsyncTask`.
When an `AsyncTask` is created we don''t want it running until started.
We accomplish this bit of magic by wrapping the passed in `future` inside of another `Future` that will only run when the `AsyncTask` is started.

Below is a bit of the `new` function:

```rust
fn new(worker: AsyncWorker<''a>, future: impl Future<Output = T> + Send + ''a) -> AsyncTask<''a, T>
where
    T: Send + std::fmt::Debug + ''a,
{
    ...

    let inner = worker.clone();
    let future = async move {
        let result = inner.spawn(future).await;
        result
    };

    Self {
        inner: Some(worker.spawn(future)),
        worker: worker.clone(),
        started: AtomicBool::new(false),
        waker: None,
        id,
    }
}
 ```

It demonstrates how we wrap the passed in `future` in another `Future`.
Note that the new, inner `Future` is made available to the `Executor` by the `AsyncWorker::spawn` function.
Also, the `AsyncTask` is created with a `started` flag set to `false`.

The second piece to the puzzle is the `Future` implementation for the `AsyncTask` type, below:

 ```rust
 impl<''a, T> Future for AsyncTask<''a, T>
where
    T: std::fmt::Debug,
{
    type Output = T;

    #[tracing::instrument(level = "trace", target = "async")]
    fn poll(self: Pin<&mut Self>, cx: &mut Context<''_>) -> Poll<Self::Output> {
        let this = std::pin::Pin::into_inner(self);

        if this.started.load(Ordering::SeqCst) {
            let task = this.inner.take().unwrap();
            Poll::Ready(future::block_on(this.worker.resolve_task(task)))
        } else {
            this.waker = Some(cx.waker().clone());
            Poll::Pending
        }
    }
}
```

The `poll` function is called when a `Future` is awaited.
Not that in the `poll` function we test the `started` flag.
If the flag is set to `true`, we take the `inner` task and resolve it using the `Executor`.
If the flag is set to `false`, we set the `waker` and return `Poll::Pending`.

### AsyncWorker

The `AsyncWorker` type is a lightweight type that wraps the `Executor` type in a smart pointer.
The `Executor` type is responsible for running tasks on the VM.
The `AsyncWorker` type is defined as follows:

```rust
pub struct AsyncWorker<''a> {
    id: usize,
    ex: Arc<SmolExecutor<''a>>,
}
```

THe `AsyncWorker` type contains an `id` and an `Arc` to `smol` `Executor`, which is aliased to `SmolExecutor`.

There are two methods on the `AsyncWorker` type that are of interest.
The first is the `spawn` method, which is used to spawn a task on the `Executor`.

```rust
fn spawn<T>(&self, future: impl Future<Output = T> + Send + ''a) -> SmolTask<T>
where
    T: Send + ''a,
{
    self.ex.spawn(future)
}
```

The `spawn` method takes a `Future` and returns a `SmolTask`.
This is used by the `AsyncTask` above.
The function is just a wrapper around the `SmolExecutor::spawn` function.

The other function we''ll look at is `resolve_task`, below:

```rust
async fn resolve_task<T>(&self, task: SmolTask<T>) -> T
where
    T: std::fmt::Debug,
{
    let result = self.ex.run(task).await;
    result
}
```

The `resolve_task` function takes a `SmolTask` and returns the result of running the task.
The function is an async function, as it awaits the result of running the task.
The function is a wrapper around the `SmolExecutor::run` function.

### The Executor

The `Executor` type is responsible for running tasks on the VM, and is backed by a smol executor.
Pūteketeke executes tasks on a thread pool.

In general, the `Executor` is used to create a new worker via `Executor::new_worker`, to start a task using `Executor::start_task`.
There are other methods on `Executor`, but they aren''t germane to this discussion.

## Async Blocks

Now back to the VM.

When we encounter an async block we need to capture the `Future` that we plan on executing and store it in a local variable for later execution.
Take the previous example:

```rust
let task = async {
    print("Hello, world!");
};

task.await;
```

In dwarf the above async block is compiled into an anonymous function.
When the program is run the async block is stuffed into a future and an `AsyncTask` is created, in the paused state.
With the information from the previous section, achieving this is as simple as:

```rust
// Create an executor with 5 threads.
let executor = Executor::new(5);

let future = async move {
    // Run a function in the dwarf VM.
    // This should be replaced with the method in your VM that executes a function.
    vm.inner_run(...)
};

let worker = executor.new_worker();
let child_task = worker.create_task(future).unwrap();

let value = new_ref!(
    Value,
    Value::Task {
        task_name,
        false,
        task: new_ref!(Option<AsyncTask<''static, ValueResult>>, Some(child_task))
    }
);

stack.push(value);
```
At this point the `child_task` variable contains the `AsyncTask` that we can pass around and await.
In dwarf we create a new `Task` and push it onto the stack.
The next instruction in the program stores the stack value in a local on the stack.

When the await instruction is reached, the task is started.
To do this we simply call `Executor::start_task()`, as shown below.
In order to recover the result the VM blocks on the task, awaiting the result, which is pushed onto the stack.

```rust
let result = match &mut expression {
    Value::Task {
        name,
        task,
        running,
    } => {
        if let Some(task) = s_write!(task).take() {
            if !*running {
                *running = true;
                executor.start_task(&task);
            }

            let f = future::block_on(task)?;
            f
        } else {
            panic!(
                "Task ({name}) is missing -- already awaited."
            );
        }
    }
    something_else => {
        panic!("Expected a task, found {something_else:?}.");
    }
};

stack.push(result);
```
## Spawning Tasks

Spawning tasks is exactly the same as the above, but we call `Executor::start_task()` immediately after creating the task.
    ')
    RETURNING id
)
INSERT INTO article (title, slug, content, published_at)
VALUES ('Async Virtual Machines in Rust', 'async-vm', (SELECT id FROM markdown_insert), TIMESTAMP '2024-06-15 00:04:20');

INSERT INTO article_tags (article_slug, tag_id)
VALUES
('async-vm', (SELECT id FROM tags WHERE tag = 'rust'));

UPDATE html
SET head = '
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-RZXB2EDQ6F"></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag("js", new Date());

      gtag("config", "G-RZXB2EDQ6F");
    </script>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" type="image/png" href="/favicon.png">
    <title>TITLE</title>
    <style>
        @import url("https://fonts.googleapis.com/css2?family=JetBrains+Mono&display=swap");

        @font-face {
            font-family: "3270";
            src: url("/3270Condensed-Regular.woff") format("woff");
            font-weight: normal;
            font-style: normal;
        }

        :root{
            --background-color: #000;
            --text-color: #fafafa;
            --code-color:  #9edc42;
            --code-border: 1px solid #fff;
        }

        body {
            background-image: url("/hacking.webp");
            background-size: cover;
            background-repeat: no-repeat;
            background-position: center;
            background-attachment: fixed;
            display: flex;
            align-items: center;
            justify-content: center;
            color:var(--text-color);
            /* White text color */
            font-family: "JetBrains Mono", monospace;
            /* Monospaced, old school feel */
        }

        /* Main Content Styles */
        .body-container {
            text-align: left;
            margin-top: 60px; /* Adjust based on nav height */
            padding: 20px;
            background-color: var(--background-color);
            border-radius: 10px;
            width: 90%;
            max-width: 800px;
            min-height: 100vh;
        }

        .body-container blockquote {
            margin: 20px;
            padding: 20px;
            background-color: #333; /* Dark background, resembling a terminal */
            border-left: 10px solid #0c7b93; /* A bright teal accent line */
            color: #8ec07c; /* Light green color typical of old monochrome monitors */
            font-family: ''Courier New'', Courier, monospace; /* Monospaced font for the code-like appearance */
            text-shadow: 0 0 3px #000; /* Text shadow for a slight glowing effect */
            box-shadow: 0 2px 5px rgba(0,0,0,0.2); /* Subtle shadow for depth */
            border-radius: 4px; /* Soften the edges */
        }

        .body-container blockquote p {
            margin: 0; /* Remove default margin */
            font-family: "3270", monospace;
            font-size: 1.5em; /* Slightly larger font size for emphasis */
        }

        .hljs {
            border:var(--code-border);
            border-radius: 10px;
            font-size: 1.2em;
        }

        .body-container p code {
            color:var(--code-color);
            font-family: monospace;
            font-size: 1.2em;
        }

        .body-container h1, .body-container h2, .body-container h3, .body-container h4, .body-container h5, .body-container h6 {
            color: green;
            /* text-shadow: 2px 2px 4px rgba(55, 155, 55, 0.5); */
        }

        .body-container h1 {
            font-size: 2em;
        }

        .body-container p {
            font-size: 1em;
        }

        .body-container a {
            display: inline-block;
            margin-top: 5px;
            padding: 0px 5px;
            background-color: #0c7b93;
            color: white;
            text-decoration: none;
            border-radius: 5px;
        }

        .body-container a:hover {
            background-color: #0a5968;
        }

        .body-container canvas {
            background-color: #000000;
        }

        /* Navigation Styles */
        .nav-container {
            background-color: rgba(0, 0, 0, 0.8);
            text-align: center;
            width: 100%;
            position: fixed;
            top: 0;
            left: 0;
            z-index: 1000;
            overflow: hidden;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        nav ul {
            list-style: none;
            padding: 0;
            margin: 0;
            width: 100%;
            display: block;
            text-align: center;
        }

        nav ul li {
            position: relative;
            display: inline-block;
        }

        nav ul li a {
            text-decoration: none;
            padding: 10px 20px;
            color: white;
            display: block;
        }

        nav ul li ul {
            display: none;
            position: absolute;
            background-color: #444;
            top: 100%;
            left: 0;
            width: 100%;
            z-index: 1001;
        }

        nav ul li:hover ul, nav ul li ul:hover {
            display: block;
        }

        .menu-toggle {
            display: none;
            background: none;
            border: none;
            color: white;
            font-size: 30px;
            cursor: pointer;
        }

        .nav-container {
            overflow: visible;
        }

        .nav-container > div {
            display: flex;
            align-items: center; /* Ensure vertical center alignment within the div */
        }

        .nav-container img {
            vertical-align: middle; /* Helps remove any line-height or font-size related issues */
        }

        .apple-id {
            margin-right: 10px;
        }

        .github {
            margin-right: 10px;
        }

        @media (max-width: 768px) {
            .body-container {
                with: 100%;
                max-width: none;
            }

            .menu-toggle {
                display: block;
            }

            nav ul {
                display: none;
                flex-direction: column;
            }

            nav ul li {
                text-align: center;
                width: 100%;
            }

            nav ul li ul {
                position: static;
            }

            nav ul li:hover ul, nav ul li ul:hover {
                display: block;
            }
        }

        .github_corner {
            position: fixed;
            bottom: 0;
            left: 0;
            border: 0;
        }

    </style>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/rust.min.js"></script>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>
    <script>hljs.highlightAll();</script>
', body = '
        <div class="github_corner">
            <a href="https://www.github.com/uberFoo" target="_blank">
                <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 250 250" fill="#fafafa" style="transform: scaleY(-1)">
                    <path fill="#fafafa" d="M250 0L135 115h-15l-12 27L0 250V0z"/>
                    <path fill="#151513" class="octo-arm" d="M122 109c15-9 9-19 9-19-3-7-2-11-2-11 1-7-3-2-3-2-4 5-2 11-2 11 3 10-5 15-9 16" style="-webkit-transform-origin: 120px 144px; transform-origin: 120px 144px"/>
                    <path fill="#151513" class="octo-body" d="M135 115s-4 2-5 0l-14-14c-3-2-6-3-8-3 8-11 15-24-2-41-5-5-10-7-16-7-1-2-3-7-12-11 0 0-5 3-7 16-4 2-8 5-12 9s-7 8-9 12c-14 4-17 9-17 9 4 8 9 11 11 11 0 6 2 11 7 16 16 16 30 10 41 2 0 3 1 7 5 11l12 11c1 2-1 6-1 6z"/>
                </svg>
            </a>
        </div>
         <div class="nav-container">
            <button class="menu-toggle" id="menu-toggle">☰</button>
            <nav>
                <ul id="menu">
                    <li><a href="/">Home</a></li>
                    <li><a href="#">Categories</a>
                        <ul>
                            <li><a href="#">Rust</a></li>
                            <li><a href="#">dwarf</a></li>
                        </ul>
                    </li>
                    <li><a href="#">About</a></li>
                    <li><a href="#">Settings</a>
                        <ul>
                            <li><a href="#" id="theme-toggle">Toggle Theme</a></li>
                        </ul>
                    </li>
                </ul>
            </nav>
            <div>
                <img src="/appleid_button@1x.png" class="apple-id" title="Sign in with Apple ID">
                <a href="https://github.com/login/oauth/authorize?client_id=fa5175ee3bcf21bf2b11&redirect_uri=https://uberfoo.com/auth/github&scope=user&state=XYZZY">
                    <img src="/github-mark-white.png" width="20" class="github" title="Sign in with GitHub">
                </a>
            </div>
        </div>

        <div class="body-container">
            MARKDOWN
            <footer style="text-align: right; padding: 20px;">
                <a href="mailto:uberfoo@me.com">✉️</a>
                <a href="https://twitter.com/share?ref_src=twsrc%5Etfw" class="twitter-share-button" data-show-count="false">Tweet</a><script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
                <a href="https://twitter.com/uberFoo?ref_src=twsrc%5Etfw" class="twitter-follow-button" data-show-count="false">Follow @uberFoo</a><script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
                <a href="https://www.github.com/uberFoo" target="_blank">
                    <img src="/github-mark-white.png" width="25">
                </a>
            </footer>
        </div>
    <script>
        document.getElementById(''theme-toggle'').addEventListener(''click'', function() {
            document.body.classList.toggle(''light-theme'');
            let theme = document.body.classList.contains(''light-theme'') ? ''light'' : ''dark'';
            localStorage.setItem(''theme'', theme);

            if (theme === ''light'') {
                // If it''s light, set the CSS variables to light colors
                document.documentElement.style.setProperty(''--background-color'', ''#fafafa'');
                document.documentElement.style.setProperty(''--text-color'', ''#000'');
                document.documentElement.style.setProperty(''--code-color'', ''#50a14f'');
                document.documentElement.style.setProperty(''--code-border'', ''1px solid #000'');
                changeHighlightTheme(''atom-one-light'');
            } else if (theme === ''dark'') {
                // If it''s dark, set the CSS variables to dark colors
                document.documentElement.style.setProperty(''--background-color'', ''#000'');
                document.documentElement.style.setProperty(''--text-color'', ''#fafafa'');
                document.documentElement.style.setProperty(''--code-color'', ''#9edc42'');
                document.documentElement.style.setProperty(''--code-border'', ''1px solid #fff'');
                changeHighlightTheme(''tomorrow-night-bright'');
            }

            redirectToPageWithTheme(theme);
        });

        document.addEventListener("DOMContentLoaded", function () {
            // Toggle main menu with the hamburger icon
            var menuToggle = document.getElementById("menu-toggle");
            menuToggle.addEventListener("click", function () {
                var menu = document.getElementById("menu");
                menu.style.display = menu.style.display === "block" ? "none" : "block";
            });
        });

        document.addEventListener("DOMContentLoaded", function() {
            var url = new URL(window.location.href);
            var theme_param = url.searchParams.get(''theme'');
            var theme = null;

            if (theme_param !== null) {
                localStorage.setItem(''theme'', theme_param);
                theme = theme_param;
            } else {
                // Get the theme from localStorage
                theme = localStorage.getItem(''theme'');
            }

            // If no theme is set in localStorage, default to ''dark''
            if (theme === null) {
                theme = ''dark'';
            }

            if (theme === ''light'') {
                // If it''s light, set the CSS variables to light colors
                document.documentElement.style.setProperty(''--background-color'', ''#fafafa'');
                document.documentElement.style.setProperty(''--text-color'', ''#000'');
                document.documentElement.style.setProperty(''--code-color'', ''#50a14f'');
                document.documentElement.style.setProperty(''--code-border'', ''1px solid #000'');
                document.body.classList.add(''light-theme'');
                changeHighlightTheme(''atom-one-light'');
            } else if (theme === ''dark'') {
                // If it''s dark, set the CSS variables to dark colors
                document.documentElement.style.setProperty(''--background-color'', ''#000'');
                document.documentElement.style.setProperty(''--text-color'', ''#fafafa'');
                document.documentElement.style.setProperty(''--code-color'', ''#9edc42'');
                document.documentElement.style.setProperty(''--code-border'', ''1px solid #fff'');
                document.body.classList.remove(''light-theme'');
                changeHighlightTheme(''tomorrow-night-bright'');
            }

            if (theme_param === null) {
                redirectToPageWithTheme(theme);
            }
        });

        function redirectToPageWithTheme(theme) {
            // Create a URL object with the current page''s URL
            var url = new URL(window.location.href);

            // Create a URLSearchParams object with the URL''s current search string
            var params = new URLSearchParams(url.search);

            // Set the ''theme'' parameter
            params.set(''theme'', theme);

            // Update the URL''s search string with the new parameters
            url.search = params.toString();

            console.log(url.toString());

            // Redirect to the new URL
            window.location.href = url.toString();
        }

        function changeHighlightTheme(themeName) {
            // Create a new link element
            var newLink = document.createElement("link");
            newLink.rel = "stylesheet";
            newLink.href = "//cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/" + themeName + ".min.css";

            // Get the existing highlight.js theme link
            var oldLink = document.querySelector(''link[href*="highlight.js"]'');

            // Replace the old theme link with the new one
            if (oldLink) {
                oldLink.parentNode.replaceChild(newLink, oldLink);
            } else {
                document.head.appendChild(newLink);
            }

            // Re-run highlight.js
            hljs.highlightAll();
        }
    </script>
'
where slug IS NULL;
