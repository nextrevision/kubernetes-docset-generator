# kubernetes-docset-generator
Script to generate a [Dash](https://kapeli.com/dash) docset for [Kubernetes](https://kubernetes.io).

NOTE: Building is only supported on OSX

## Building

Ensure the following dependencies have been installed:

* git (`brew install git`)
* wget (`brew install wget`)
* jekyll (`gem install github-pages`)
* PlistBuddy (`/usr/libexec/PlistBuddy`)

```
VERSION=1.4 ./build.sh docset
```

You will then see the following files: `Kubernetes.tgz` and `kubernetes.docset`. You can test out the generated docset by opening Dash and going to `Preferences > Docsets > +` and adding browsing to the path of the `kubernetes.docset` file.

### Generating Guides, Commands, and Glossary Lists for `dashing.json`

To generate a list of guides, commands, and glossary items to populate the `dashing.json` list, run the build script with the `lists` command:

```
VERSION=1.4 ./build.sh lists
```
