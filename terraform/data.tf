data template_file indexjs {

  depends_on = [aws_sns_topic.topic]
  
  template   = file("${path.module}/indexjs.template")

  vars = {
    topicarn = aws_sns_topic.topic.arn
  }
}
