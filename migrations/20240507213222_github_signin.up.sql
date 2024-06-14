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
        @import url("https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/tomorrow-night-bright.css");
        @import url("https://fonts.googleapis.com/css2?family=JetBrains+Mono&display=swap");

        @font-face {
            font-family: "3270";
            src: url("/3270Condensed-Regular.woff") format("woff");
            font-weight: normal;
            font-style: normal;
        }

        :root{
            --background-color: #000;
            --text-color: #ddd;
            --code-color:  #9edc42;
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
            background: rgba(0, 0, 0, 0.5);
            pointer-events: none;
            z-index: -1;
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
            border: 1px solid #fff;
            border-radius: 10px;
            background: #000;
            font-size: 1.2em;
            font-family: "3270", monospace;
        }

        .body-container code {
            color:var(--code-color);
            background: #000;
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
                <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 250 250" fill="#ddd" style="transform: scaleY(-1)">
                    <path fill="#ddd" d="M250 0L135 115h-15l-12 27L0 250V0z"/>
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
                document.documentElement.style.setProperty(''--background-color'', ''#ddd'');
                document.documentElement.style.setProperty(''--text-color'', ''#000'');
                document.documentElement.style.setProperty(''--code-color'', ''#ddd'');
            } else if (theme === ''dark'') {
                // If it''s dark, set the CSS variables to dark colors
                document.documentElement.style.setProperty(''--background-color'', ''#000'');
                document.documentElement.style.setProperty(''--text-color'', ''#ddd'');
                document.documentElement.style.setProperty(''--code-color'', ''#9edc42'');
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
                document.documentElement.style.setProperty(''--background-color'', ''#ddd'');
                document.documentElement.style.setProperty(''--text-color'', ''#000'');
                document.documentElement.style.setProperty(''--code-color'', ''#ddd'');
                document.body.classList.add(''light-theme'');
            } else if (theme === ''dark'') {
                // If it''s dark, set the CSS variables to dark colors
                document.documentElement.style.setProperty(''--background-color'', ''#000'');
                document.documentElement.style.setProperty(''--text-color'', ''#ddd'');
                document.documentElement.style.setProperty(''--code-color'', ''#9edc42'');
                document.body.classList.remove(''light-theme'');
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
    </script>
'
where slug IS NULL;
