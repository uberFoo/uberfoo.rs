DROP TABLE IF EXISTS article;
DROP TABLE IF EXISTS markdown;

-- This table stores the text for a page. That text is expected to be markdown.
CREATE TABLE markdown
(
    id SERIAL PRIMARY KEY,
    markdown TEXT
);

-- This is the main table for a blog post.
CREATE TABLE article
(
    slug VARCHAR(255) PRIMARY KEY,
    title VARCHAR(255),
    content INTEGER REFERENCES markdown(id),
    is_published BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION update_article(_slug VARCHAR(255), _is_published BOOLEAN)
RETURNS VOID AS $$
BEGIN
    UPDATE article
    SET is_published = _is_published,
        published_at = CASE WHEN _is_published THEN CURRENT_TIMESTAMP ELSE NULL END
    WHERE slug = _slug;
END;
$$ LANGUAGE plpgsql;

-- Insert posts
-- Insert the markdown
WITH markdown_insert AS (
    INSERT INTO markdown (markdown)
    VALUES ('
I have a lot to say about shared libraries, both with regards to [Rust](https://www.rust-lang.org) as well as [dwarf](https://github.com/uberFoo/dwarf).
What I plan on doing is discussing how to safely load shared libraries in Rust.
Then I''m going to talk about how dwarf leverages the former to extend the language.

## Shared Libraries in Rust

Loading a shared library in rust isn''t difficult.
Ensuring that types work across the FFI boundary is non-trivial because Rust doesn''t have a stable ABI.
In fact, there''s a crate called [abi_stable](https://docs.rs/abi_stable/latest/abi_stable/) to help.

I won''t try to describe what `abi_stable` does.
Instead I''ll quote from the documentation:

> [abi_stable is] For Rust-to-Rust ffi, with a focus on creating libraries loaded at program startup, and with load-time type-checking.
>
> This library allows defining Rust libraries that can be loaded at runtime, even if they were built with a different Rust version than the crate that depends on it.

When I was adding plugins to dwarf, my biggest challenge was figuring out how to make it all work end-to-end with the `abi_stable` crate.
Given the effort and time it took, it makes sense to document the process here.

To be clear the goal is to load a shared library that contains functions that enable some external functionality.

> **`abi_stable` is Complicated**
>
> I got it working, and left it at that.
> There are aspects of the crate that are completely unfamiliar to me.
> What I am documenting is what worked for my application.
> Hopefully someone else will find some use for this.

### Plugin API

The first thing that we want to do is determine the API that we''d like to have.
The API is exposed as a trait, with the `#[sabi_trait]` attribute.

For dwarf we want to be able to create new instances, and invoke arbitrary methods on them.
For example,

```rust
use sqlx::Sqlx;

fn main() {
    let s = Sqlx::new()
    s.connect(...);
}
```

To achieve this sort of generality we need to pass along all of the information needed to invoke a method.
We can do this by simply passing in the constituent bits of the method call.
In the first line of the above example we can see that the type is "Sqlx", and the method name is "new".
In the second line, we can infer the type, and the method name is "connect".
In both cases, the module is "sqlx".
We''ve essentially factored out what we need to make this work.
The results are below in the function `invoke_func`.
`invoke_func` simply takes the `module`, `ty`, and `name` as `RStr`s, in addition to the function arguments.

The following code comes from [plug_in.rs](https://github.com/uberFoo/dwarf/blob/develop/src/plug_in.rs) in the dwarf source tree.

```rust
#[sabi_trait]
pub trait Plugin: Clone + Debug + Display + Send + Sync {
    fn invoke_func(
        &self,
        module: RStr<''_>,
        ty: RStr<''_>,
        name: RStr<''_>,
        args: RVec<FfiValue>,
    ) -> RResult<FfiValue, Error>;

    fn invoke_func_mut(
        &mut self,
        module: RStr<''_>,
        ty: RStr<''_>,
        name: RStr<''_>,
        args: RVec<FfiValue>,
    ) -> RResult<FfiValue, Error>;

    #[sabi(last_prefix_field)]
    fn name(&self) -> RStr<''_>;
}

pub type PluginType = Plugin_TO<''static, RBox<()>>;
```

Now what''s this `RStr` type?
Well, we are limited in what we send across the FFI boundary, as well as how we send it.
`abi_stable` has FFI-friendly analogs of most of the Rust types, as well as a few others.
`RStr` is the FFI-friendly `&str` analog.
There are also `RResult`, `ROk`, `RString`, etc., as well as [crossbeam](https://docs.rs/crossbeam/latest/crossbeam/) channels.

Note the `FfiValue` type that is returned by `invoke_func`, as well as accepted as input arguments.
This is an FFI-safe version of dwarf''s value type.
Since dwarf runs in a VM, it needs a uniform type to pass around.
The value type is an enum that has many variants, including Integer, Float, etc.

Additionally there is `invoke_func_mut`, for when you really need to mutate `self`.
Note that this comes with a price: a mutex gets locked and any attempt at re-entrance will deadlock.

Finally is the `name` method, which returns the name of the plugin.
Note the attribute above `name`.
This get''s shuffled around after you''ve released a version, and later add fields.
I **have not** used this, and I''m not really familiar with it.

Also note the `PluginType` type.
It is an alias for the trait object that is generated by the `#[sabi_trait]` attribute.
It is used below, in the `PluginModule` type.

`PluginModule` is a struct that we need to define that ties together the trait above, and

```rust
#[repr(C)]
#[derive(StableAbi)]
#[sabi(kind(Prefix(prefix_ref = PluginModRef)))]
#[sabi(missing_field(panic))]
pub struct PluginModule {
    pub name: extern "C" fn() -> RStr<''static>,
    #[sabi(last_prefix_field)]
    pub new: extern "C" fn(RSender<LambdaCall>, RVec<FfiValue>) -> RResult<PluginType, Error>,
}

impl RootModule for PluginModRef {
    declare_root_module_statics! {PluginModRef}
    const BASE_NAME: &''static str = "plugin";
    const NAME: &''static str = "plugin";
    const VERSION_STRINGS: VersionStrings = package_version_strings!();
}
```

The struct `PluginModule` is the means we are given to create a new plugin.
I don''t have a lot of insight into `RootModule` impl.
I just set it up with some generic strings and left it like I found it in the example code.

## Plugin Implementation

That was the setup.
Now we take a look at the implementation side of the plugin.
These code snippets come from the [sqlx](https://github.com/launchbadge/sqlx) dwarf [plugin](https://github.com/uberFoo/dwarf/blob/develop/plugins/sqlx/src/lib.rs).

This first snippet is really the magic that makes the whole thing work

```rust
#[export_root_module]
pub fn instantiate_root_module() -> PluginModRef {
    PluginModule { name, new }.leak_into_prefix()
}
```

```rust
#[sabi_extern_fn]
pub fn name() -> RStr<''static> {
    "sqlx".into()
}

/// Instantiates the plugin.
#[sabi_extern_fn]
pub fn new(
    lambda_sender: RSender<LambdaCall>,
    _args: RVec<FfiValue>,
) -> RResult<PluginType, Error> {
    let plugin = postgres::instantiate_root_module();
    let plugin = plugin.new();
    let plugin = plugin(lambda_sender, vec![].into()).unwrap();
    ROk(Plugin_TO::from_value(plugin, TD_Opaque))
}
```

```rust
let library_path = RawLibrary::path_in_directory(
    Path::new(&format!(
        "{}/extensions/{}/lib",
        self.home.display(),
        plugin_root,
    )),
    plugin_root.as_str(),
    LibrarySuffix::NoSuffix,
);
let root_module = (|| {
    let header = lib_header_from_path(&library_path)?;
    header.init_root_module::<PluginModRef>()
})()
.map_err(|e| {
    if self.backtrace {
        eprintln!("{self:?}");
        print_stack(&stack, fp);
    }
    BubbaError::VmPanic {
        message: format!("Plug-in error: {e}."),
        location: location!(),
    }
})?;
let ctor = root_module.new();
let plugin = ctor(self.lambda_sender.clone().into(), args.into()).unwrap();
```

## Plugins in dwarf

Plugins are the primary method for adding functionality to the language, as libraries.
To load a plugin in dwarf, you just use it: `use sqlx::Sqlx`.
')
    RETURNING id
)
    -- Insert the article
INSERT INTO article (title, slug, content, published_at)
VALUES ('Plugins in Rust', 'plugins', (SELECT id FROM markdown_insert), TIMESTAMP '2024-04-23 00:04:20');

-- This is a table to hold the html that comes before and after the markdown
-- from the article.
CREATE TABLE html
(
    slug VARCHAR(255) PRIMARY KEY,
    head TEXT,
    body TEXT
);

INSERT INTO html (slug, head, body)
VALUES('__default_dont_be_dumb__',
-- VALUES('plugins',
'
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-RZXB2EDQ6F"></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag("js", new Date());

      gtag("config", "G-RZXB2EDQ6F");
    </script>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TITLE</title>
    <style>
        @import url("https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/tomorrow-night-bright.css");
        @import url("https://fonts.googleapis.com/css2?family=JetBrains+Mono&display=swap");

        @font-face {
            font-family: "3270";
            src: url("/3270Condensed-Regular.woff") format("woff");
            font-weight: normal;
            font-style: normal;
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
            color: #fff;
            /* White text color */
            font-family: "JetBrains Mono", monospace;
            /* Monospaced, old school feel */
        }

        body::before {
            content: "";
            position: fixed;
            top: 0;
            right: 0;
            bottom: 0;
            left: 0;
            background-image: url("/hacking.webp");
            background-size: cover;
            background-repeat: no-repeat;
            background-position: center;
            z-index: -1;
        }

        .body-container {
            text-align: left;
            margin-top: 60px;
            padding: 20px;
            background-color: rgba(0, 0, 0, 0.8);
            /* Semi-transparent black background for readability */
            border-radius: 10px;
            width: 90%;
            /* Adjust based on layout needs */
            max-width: 800px;
            /* Maximum width */
            min-height: 100vh;
        }

        @media (max-width: 600px) {
            .body-container {
                with: 100%;
                max-width: none;
            }
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

        .body-container code {
            border-radius: 10px;
            color: #9edc8f;
            font-size: 1.2em;
            font-family: "3270", monospace;
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

        .nav-container {
            background-color: rgba(0, 0, 0, 0.8); /* Semi-transparent black */
            text-align: center;
            box-shadow: 0 2px 4px rgba(0,0,0,0.5); /* Soft shadow for depth */
            padding: 10px 0; /* Padding to give some space inside the container */
            width: 100%; /* Full width */
            position: fixed; /* Fixed at the top */
            top: 0;
            left: 0;
            z-index: 1000; /* Ensure it''s above other content */
        }

        nav ul {
            list-style: none;
            padding: 0;
            margin: 0;
            display: inline-block; /* Centering the nav list if text-align is center */
        }

        nav ul li {
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
        }

        nav ul li:hover ul {
            display: block; /* Show dropdown on hover */
        }

        nav ul li ul li {
            display: block;
        }

    </style>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/rust.min.js"></script>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>
    <script>hljs.highlightAll();</script>
',
'
        <div class="nav-container">
            <nav>
                <ul>
                    <li><a href="/">Home</a></li>
                    <li><a href="/categories">Categories</a>
                        <ul>
                            <li><a href="/category/technology">Technology</a></li>
                            <li><a href="/category/lifestyle">Lifestyle</a></li>
                            <!-- More categories -->
                        </ul>
                    </li>
                    <li><a href="/about">About</a></li>
                    <li><a href="/archive">Archive</a></li>
                    <li><a href="/contact">Contact</a></li>
                </ul>
            </nav>
        </div>

        <div class="body-container">
            MARKDOWN
            <footer style="text-align: right; padding: 20px;">
                <a href="mailto:uberfoo@me.com">Reach out!</a>
                <a href="https://twitter.com/share?ref_src=twsrc%5Etfw" class="twitter-share-button" data-show-count="false">Tweet</a><script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
                <a href="https://twitter.com/uberFoo?ref_src=twsrc%5Etfw" class="twitter-follow-button" data-show-count="false">Follow @uberFoo</a><script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
                <a href="https://www.github.com/uberFoo" target="_blank">
                    <img src="/github-mark-white.png" width="25">
                </a>
            </footer>
        </div>
')