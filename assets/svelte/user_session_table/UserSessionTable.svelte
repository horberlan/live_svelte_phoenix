<script>
  let counterSec = 11

  function startTimerCountdown() {
    const interval = setInterval(() => {
      if (counterSec > 0) {
        counterSec -= 1
      } else {
        clearInterval(interval)
      }
    }, 1000)
  }

  startTimerCountdown()
</script>

<div class="overflow-x-auto">
  <table class="table table-zebra">
    <thead>
      <tr>
        <th></th>
        <th>Title</th>
        <th>Session Id</th>
        <th>Expires in</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <th>1</th>
        <td>lorem ipsum</td>
        <td>XXXXX</td>
        <td class="countdown">
          <span style={`--value:${counterSec};`}>{counterSec}</span>h
          <span style={`--value:${counterSec};`}>{counterSec}</span>m
          <span style={`--value:${counterSec};`}>{counterSec}</span>s
        </td>
      </tr>
    </tbody>
  </table>
</div>
