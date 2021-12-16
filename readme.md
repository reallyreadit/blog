This is the repository for [blog.readup.com](https://blog.readup.com), a [Jekyll](jekyllrb.com/) blog.

## Installation
- [Install Jekyll](https://jekyllrb.com/docs/installation/).
    - Make sure to add the directory for Ruby gems binaries to your path (the installer should warn you about this with instructions), e.g. `export PATH=$PATH:/Users/thor/.gem/ruby/2.6.0/bin`.
    - For Thor's recent macOS installation on Big Sur, no additional ruby runtime needed to be installed, but rdoc needed to be installed to avoid an error. This worked:
        ```
        gem install --user-install rdoc bundler jekyll
        ```
    
- Run `bundle install` to install dependencies.

## Development

Run `./run.sh` in your terminal to start a live development server.

## Deployment
- Install the [AWS CLI](https://aws.amazon.com/cli/)
- TODO