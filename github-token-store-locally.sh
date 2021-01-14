# tokens and passwords must not be commited to the git repo
# instead we will store them locally like so

mkdir ~/.github
echo "aws-bootstrap" > ~/.github/aws-bootstrap-repo
echo "<username>" > ~/.github/aws-bootstrap-owner
echo "<token>" > ~/.github/aws-bootstrap-access-token