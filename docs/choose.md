# Help me choose

Start with what you want to make. This chooser suggests a starting point and a
Copier command. You can change the template's other settings when Copier asks.

<!-- The interactive form needs HTML controls that Markdown cannot express. -->
<!-- rumdl-disable MD033 -->
<div data-chooser-root class="chooser">
<p data-chooser-loading>The chooser needs JavaScript. You can also <a href="usage.md#choosing-your-stacks">choose your stacks in the usage guide</a> or use the <a href="https://github.com/simonvanlierde/project-templates#quick-start">GitHub quick start</a>.</p>
<form data-chooser hidden>
<fieldset>
<legend>What are you making?</legend>
<label><input type="radio" name="task" value="package"> A reusable package</label>
<label><input type="radio" name="task" value="tool"> A tool or service</label>
<label><input type="radio" name="task" value="research"> Research or a data project</label>
<label><input type="radio" name="task" value="website"> A website</label>
</fieldset>
<fieldset data-question="tool" hidden disabled>
<legend>What will it do?</legend>
<label for="chooser-tool">Type of tool or service</label>
<select id="chooser-tool" name="tool">
<option value="">Choose an option</option>
<option value="app">Run a program I write</option>
<option value="service">Serve an HTTP API with Python</option>
<option value="compose">Run existing container images together</option>
</select>
</fieldset>
<fieldset data-question="research" hidden disabled>
<legend>How will you work with data?</legend>
<label for="chooser-research">Type of research or data project</label>
<select id="chooser-research" name="research">
<option value="">Choose an option</option>
<option value="notebooks">Analyse data and run experiments, with notebooks</option>
<option value="pipeline">Fetch, build and validate data in repeatable steps</option>
</select>
</fieldset>
<fieldset data-question="website" hidden disabled>
<legend>What kind of website?</legend>
<label for="chooser-website">Type of website</label>
<select id="chooser-website" name="website">
<option value="">Choose an option</option>
<option value="app">An interactive browser app</option>
<option value="static">A static page or content site</option>
</select>
</fieldset>
<fieldset data-question="language" hidden disabled>
<legend>Which language will you use?</legend>
<label for="chooser-language">Language</label>
<select id="chooser-language" name="language">
<option value="">Choose a language</option>
<option value="python">Python</option>
<option value="ts">TypeScript</option>
<option value="rust">Rust</option>
<option value="go">Go</option>
</select>
</fieldset>
</form>
<div data-chooser-static hidden>
<h2>Start with the static site guide</h2>
<p>The template offers a plain HTML page or an Astro site alongside a project. The <a href="hosting.md#static-site">static site guide</a> explains those choices and hosting.</p>
</div>
<section data-chooser-result hidden aria-labelledby="chooser-result-title">
<h2 id="chooser-result-title" data-chooser-title></h2>
<p data-chooser-reason></p>
<h3>Files to start with</h3>
<ul data-chooser-files></ul>
<h3>Create the project</h3>
<p>Install the tools listed in the <a href="https://github.com/simonvanlierde/project-templates#quick-start">GitHub quick start</a>. Create a new, empty directory and initialise Git there:</p>
<pre><code>mkdir my-project
cd my-project
git init</code></pre>
<p>Run this command inside that directory:</p>
<pre class="chooser-command"><code data-chooser-command></code></pre>
<button type="button" data-chooser-copy>Copy Copier command</button>
<p data-chooser-status role="status"></p>
<p>The command uses the latest released template. Copier asks for the remaining details, including the project owner and author. A web app also asks what user data it keeps. Choose advanced settings in Copier if you need different defaults.</p>
<h3>Run the first checks</h3>
<p>First, complete the Development setup in your generated README. It installs the
extra tools your project needs. Then run these commands in order:</p>
<ol data-chooser-checks></ol>
<p>Follow the generated README for setup and deployment. A web app's Cloudflare deployment needs account configuration; creating the files does not deploy it.</p>
</section>
</div>

<details>
<summary>Advanced settings and other combinations</summary>
<p>This chooser covers one main task at a time. Copier also supports multiple stacks, nested packages, publishing and optional checks. The <a href="usage.md#the-questions">question reference</a> explains the full set of settings.</p>
<p>For an existing repository, use the <a href="updates.md#adopting-the-template-in-an-existing-repo">adoption guides</a> before rendering over its files.</p>
</details>
