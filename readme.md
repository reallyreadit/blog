This is the repository for [blog.readup.com](https://blog.readup.com), a [Jekyll](jekyllrb.com/) blog.

## Installation

### With Docker

This is probably the easiest, because this project relies on outdated Jekyll, ruby and ruby gem dependencies. This might clash with what's installed on your system already (especially on macOS).

From within this directory, run:

To run a live development server at `http://localhost:4000`:
```
docker run --rm \
  --volume="$PWD:/srv/jekyll:Z" \
  -p 4000:4000 \
  -it jekyll/jekyll:4.1.0 \
jekyll serve
```

To build the site a single time:
```
docker run --rm \
  --volume="$PWD:/srv/jekyll:Z" \
  -it jekyll/jekyll:4.1.0 \
jekyll build
```

To rebuild the site on each file change, add `-w` after jekyll build.

### Manual installation & usage

- [Install Jekyll](https://jekyllrb.com/docs/installation/).
    - Make sure to add the directory for Ruby gems binaries to your path (the installer should warn you about this with instructions), e.g. `export PATH=$PATH:/Users/thor/.gem/ruby/2.6.0/bin`.
    - For Thor's recent macOS installation on Big Sur, no additional ruby runtime needed to be installed, but rdoc needed to be installed to avoid an error. This worked:
        ```
        gem install --user-install rdoc bundler jekyll
        ```
    
- Run `bundle install` to install dependencies.
- Run `./run.sh` in your terminal to start a live development server.

## Deployment

### Get & configure the AWS CLI
1. Install the [AWS CLI](https://aws.amazon.com/cli/)
2. If you're here, you likely already received an IAM user account with proper admin permissions. You'll need it.
3. [Create an access key ID and secret access key](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-prereqs.html#getting-started-prereqs-keys), if you haven't already.
4. Follow the [Quick Setup](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html) to configure your CLI. The default region of Readup is `us-east-2`. To use the deployment commands here as-is, you should configure the `reallyreadit` profile:
    `aws configure --profile reallyreadit`
5. Check if you can access the S3 blog bucket with `aws s3 ls s3://blog.readup.com --region us-east-2`

### Publishing

TODO: instructions don't work with Docker yet here.

Run `./publish.sh`